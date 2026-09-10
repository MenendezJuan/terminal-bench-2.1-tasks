package io.github.hectorvent.floci.services.kinesis;

import com.fasterxml.jackson.core.type.TypeReference;
import io.github.hectorvent.floci.core.common.RegionResolver;
import io.github.hectorvent.floci.core.storage.InMemoryStorage;
import io.github.hectorvent.floci.core.storage.WalStorage;
import io.github.hectorvent.floci.services.kinesis.model.KinesisRecord;
import io.github.hectorvent.floci.services.kinesis.model.KinesisShard;
import io.github.hectorvent.floci.services.kinesis.model.KinesisStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Behavior-only concurrency regression coverage for KinesisService.
 *
 * These tests deliberately avoid the upstream PR's private test seams
 * (putRecordAppendHook / putRecordBeforeLockHook) and any helper method the
 * fix itself introduces. Every call here is a stable public entry point that
 * exists on both the pre-fix and post-fix source, so this file compiles and
 * runs unmodified against either. Races are driven by real concurrent load
 * over enough iterations to be reliable, not by sleeps or clock assumptions.
 *
 * The four underlying invariants are pre-registered, independent scoring
 * units (see JC_TASK_06_SELECTION.md), but they are deliberately GROUPED
 * into two semantic gates here rather than graded as four separate F2P
 * entries: durability/order and lifecycle/topology are the two natural
 * user-facing contracts a caller of this service depends on, and a fix
 * that satisfies one invariant inside a contract while silently breaking
 * a sibling invariant in the same contract (for example, synchronizing
 * append but leaving deleteStream unlocked) must fail that whole gate, not
 * survive as a single failing leaf out of four. This grouping was fixed
 * BEFORE any model was run against this task -- see the mutation-testing
 * note in PROVENANCE.json.
 */
class KinesisConcurrencyBehaviorTest {

    private static final String REGION = "us-east-1";

    private KinesisService kinesisService;

    @TempDir
    Path tmp;

    @BeforeEach
    void setUp() {
        kinesisService = new KinesisService(
                new InMemoryStorage<>(),
                new InMemoryStorage<>(),
                new RegionResolver(REGION, "000000000000"));
    }

    private List<Throwable> runConcurrently(int threadCount, Runnable op) throws InterruptedException {
        ExecutorService pool = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startGate = new CountDownLatch(1);
        CountDownLatch doneGate = new CountDownLatch(threadCount);
        List<Throwable> errors = Collections.synchronizedList(new ArrayList<>());
        try {
            for (int t = 0; t < threadCount; t++) {
                pool.submit(() -> {
                    try {
                        startGate.await();
                        op.run();
                    } catch (Throwable e) {
                        errors.add(e);
                    } finally {
                        doneGate.countDown();
                    }
                });
            }
            startGate.countDown();
            assertTrue(doneGate.await(30, TimeUnit.SECONDS), "concurrent operations did not finish in time");
        } finally {
            pool.shutdownNow();
        }
        return errors;
    }

    // ─── Gate 1: durability and order ──────────────────────────────────────

    /**
     * Gate 1: accepted-record durability and order, in memory and across a
     * WAL reload. Fails if EITHER sub-check below fails, so a fix that
     * protects one write path but not the other still fails this gate.
     */
    @Test
    void durabilityAndOrderGate() throws Exception {
        noSilentLossAndStrictOrder();
        survivesWalReload();
    }

    /**
     * 24 threads each put 50 records to a single-shard stream, all released
     * together. Every accepted PutRecord must be retrievable afterward, with
     * no silent loss and no partition-key gaps, and sequence numbers must be
     * strictly increasing end to end -- a plain, unsynchronized ArrayList
     * append loses writes under this load; a per-stream critical section
     * that serializes selection + append does not.
     */
    private void noSilentLossAndStrictOrder() throws Exception {
        kinesisService.createStream("durability-stream", 1, REGION);
        int threads = 24;
        int opsPerThread = 50;
        int expected = threads * opsPerThread;
        AtomicInteger idSource = new AtomicInteger();

        List<Throwable> errors = runConcurrently(threads, () -> {
            for (int i = 0; i < opsPerThread; i++) {
                int id = idSource.getAndIncrement();
                byte[] data = ("payload-" + id).getBytes(StandardCharsets.UTF_8);
                kinesisService.putRecordWithShardId("durability-stream", data, "key-" + id, REGION);
            }
        });
        assertTrue(errors.isEmpty(), () -> "unexpected errors during concurrent put: " + errors);

        KinesisStream stream = kinesisService.describeStream("durability-stream", REGION);
        String shardId = stream.getShards().getFirst().getShardId();
        String iterator = kinesisService.getShardIterator("durability-stream", shardId, "TRIM_HORIZON", null, REGION);

        List<KinesisRecord> drained = new ArrayList<>();
        while (true) {
            Map<String, Object> page = kinesisService.getRecords(iterator, 1000, REGION);
            @SuppressWarnings("unchecked")
            List<KinesisRecord> records = (List<KinesisRecord>) page.get("Records");
            if (records.isEmpty()) {
                break;
            }
            drained.addAll(records);
            iterator = (String) page.get("NextShardIterator");
            if (iterator == null) {
                break;
            }
        }

        assertEquals(expected, drained.size(), "every accepted PutRecord must be retrievable, none silently lost");

        Set<String> seenPayloads = new HashSet<>();
        long previousSeq = Long.MIN_VALUE;
        for (KinesisRecord record : drained) {
            seenPayloads.add(new String(record.getData(), StandardCharsets.UTF_8));
            long seq = Long.parseLong(record.getSequenceNumber());
            assertTrue(seq > previousSeq, "sequence numbers must be strictly increasing end to end");
            previousSeq = seq;
        }
        Set<String> expectedPayloads = new HashSet<>();
        for (int i = 0; i < expected; i++) {
            expectedPayloads.add("payload-" + i);
        }
        assertEquals(expectedPayloads, seenPayloads, "the drained payload set must match exactly, with no gaps");
    }

    /**
     * A process restart must replay every record that concurrent producers
     * appended, in the same strict sequence order, exercising the on-disk
     * write path rather than only the in-memory one. Uses only the
     * pre-existing WalStorage backend; nothing here is new to the fix.
     */
    private void survivesWalReload() throws Exception {
        Path snapshot = tmp.resolve("kinesis-streams.json");
        Path wal = tmp.resolve("kinesis-streams.wal");
        RegionResolver rr = new RegionResolver(REGION, "000000000000");

        int threads = 16;
        int opsPerThread = 40;
        int expected = threads * opsPerThread;
        byte[] data = "payload".getBytes(StandardCharsets.UTF_8);

        WalStorage<String, KinesisStream> store1 = new WalStorage<>(
                snapshot, wal, new TypeReference<Map<String, KinesisStream>>() {}, 3_600_000L);
        WalStorage<String, KinesisStream> store2 = null;
        try {
            store1.load();
            KinesisService writer = new KinesisService(store1, new InMemoryStorage<>(), rr);
            writer.createStream("wal-stream", 1, REGION);

            List<Throwable> errors = runConcurrently(threads, () -> {
                for (int i = 0; i < opsPerThread; i++) {
                    writer.putRecordWithShardId("wal-stream", data, "pk", REGION);
                }
            });
            assertTrue(errors.isEmpty(), () -> "unexpected errors: " + errors);

            Path snapshot2 = tmp.resolve("reload-streams.json");
            Path wal2 = tmp.resolve("reload-streams.wal");
            Files.copy(wal, wal2, StandardCopyOption.REPLACE_EXISTING);
            if (Files.exists(snapshot)) {
                Files.copy(snapshot, snapshot2, StandardCopyOption.REPLACE_EXISTING);
            }

            store2 = new WalStorage<>(
                    snapshot2, wal2, new TypeReference<Map<String, KinesisStream>>() {}, 3_600_000L);
            store2.load();
            KinesisService reader = new KinesisService(store2, new InMemoryStorage<>(), rr);

            String shardId = reader.describeStream("wal-stream", REGION).getShards().getFirst().getShardId();
            String iterator = reader.getShardIterator("wal-stream", shardId, "TRIM_HORIZON", null, REGION);
            List<KinesisRecord> all = new ArrayList<>();
            while (true) {
                Map<String, Object> page = reader.getRecords(iterator, 1000, REGION);
                @SuppressWarnings("unchecked")
                List<KinesisRecord> records = (List<KinesisRecord>) page.get("Records");
                if (records.isEmpty()) {
                    break;
                }
                all.addAll(records);
                iterator = (String) page.get("NextShardIterator");
                if (iterator == null) {
                    break;
                }
            }

            assertEquals(expected, all.size(), "every record must survive the WAL reload");

            Set<String> distinct = new HashSet<>();
            all.forEach(r -> distinct.add(r.getSequenceNumber()));
            assertEquals(expected, distinct.size(), "every reloaded record must carry a distinct sequence");

            long previous = Long.MIN_VALUE;
            for (KinesisRecord r : all) {
                long current = Long.parseLong(r.getSequenceNumber());
                assertTrue(current > previous, "reloaded records must be in strictly increasing sequence order");
                previous = current;
            }
        } finally {
            if (store2 != null) {
                store2.shutdown();
            }
            store1.shutdown();
        }
    }

    // ─── Gate 2: lifecycle and topology integrity ──────────────────────────

    /**
     * Gate 2: a deleted stream must stay deleted under concurrent load, and
     * a concurrent shard split must never expose an inconsistent or
     * exception-throwing view of the shard topology. Fails if EITHER
     * sub-check below fails, so a fix that locks appends against splits but
     * not against deletes (or vice versa) still fails this gate.
     */
    @Test
    void lifecycleAndTopologyGate() throws Exception {
        neverResurrectsADeletedStream();
        readerNeverThrowsOrSeesHalfPublishedChildren();
    }

    /**
     * A stream deleted mid-flight must stay deleted: a producer that already
     * resolved the stream before the delete committed must not be able to
     * write to and re-persist that stale, now-deleted instance afterward.
     * Runs many independent trials, each with a fresh stream and enough
     * concurrent producers writing in a tight loop that at least one write
     * lands in the pre-delete resolve window on the unfixed code, without
     * relying on any sleep or fixed timing offset.
     */
    private void neverResurrectsADeletedStream() throws Exception {
        int trials = 40;
        for (int trial = 0; trial < trials; trial++) {
            String streamName = "lifecycle-stream-" + System.nanoTime();
            kinesisService.createStream(streamName, 1, REGION);

            int producerThreads = 8;
            AtomicBoolean stop = new AtomicBoolean(false);
            AtomicInteger idSource = new AtomicInteger();

            ExecutorService pool = Executors.newFixedThreadPool(producerThreads);
            List<Throwable> errors = Collections.synchronizedList(new ArrayList<>());
            CountDownLatch producersDone = new CountDownLatch(producerThreads);
            try {
                for (int t = 0; t < producerThreads; t++) {
                    pool.submit(() -> {
                        try {
                            while (!stop.get()) {
                                int id = idSource.getAndIncrement();
                                try {
                                    kinesisService.putRecordWithShardId(streamName,
                                            ("v" + id).getBytes(StandardCharsets.UTF_8), "k" + id, REGION);
                                } catch (RuntimeException ignoredAfterDelete) {
                                    // Expected once the stream is gone: a fresh resolve must fail closed.
                                }
                            }
                        } catch (Throwable e) {
                            errors.add(e);
                        } finally {
                            producersDone.countDown();
                        }
                    });
                }
                Thread deleter = new Thread(() -> kinesisService.deleteStream(streamName, REGION));
                deleter.start();
                deleter.join(TimeUnit.SECONDS.toMillis(10));
                assertFalse(deleter.isAlive(), "deleteStream did not complete in time");

                int opsAtDelete = idSource.get();
                int extraOpsTarget = opsAtDelete + 500;
                while (idSource.get() < extraOpsTarget) {
                    Thread.onSpinWait();
                }
            } finally {
                stop.set(true);
                assertTrue(producersDone.await(10, TimeUnit.SECONDS), "producer threads did not stop in time");
                pool.shutdownNow();
            }
            assertTrue(errors.isEmpty(), () -> "unexpected errors: " + errors);

            final String name = streamName;
            assertThrows(RuntimeException.class,
                    () -> kinesisService.describeStream(name, REGION),
                    "a stream deleted mid-flight must never be resurrected by a racing producer (trial " + trial + ")");
        }
    }

    /**
     * A lock-free reader repeatedly snapshotting the live shard list must
     * never throw while a concurrent split appends to it, and must never
     * observe a split parent with only one of its two children -- a plain
     * ArrayList throws ConcurrentModificationException under this load and
     * exposes a two-step append as a visible half-published topology; a
     * copy-on-write list with a single atomic two-child publish does not.
     * Runs several independent trials, each on a fresh stream.
     */
    private void readerNeverThrowsOrSeesHalfPublishedChildren() throws Exception {
        int trials = 3;
        for (int trial = 0; trial < trials; trial++) {
            String streamName = "reshard-stream-" + trial;
            kinesisService.createStream(streamName, 1, REGION);
            KinesisStream stream = kinesisService.describeStream(streamName, REGION);

            AtomicReference<String> violation = new AtomicReference<>();
            AtomicBoolean done = new AtomicBoolean(false);

            Thread reader = new Thread(() -> {
                while (!done.get()) {
                    try {
                        List<KinesisShard> snapshot = new ArrayList<>(stream.getShards());
                        Map<String, Integer> splitChildCount = new java.util.HashMap<>();
                        for (KinesisShard s : snapshot) {
                            if (s.getParentShardId() != null && s.getAdjacentParentShardId() == null) {
                                splitChildCount.merge(s.getParentShardId(), 1, Integer::sum);
                            }
                        }
                        for (Map.Entry<String, Integer> e : splitChildCount.entrySet()) {
                            if (e.getValue() != 2) {
                                violation.compareAndSet(null,
                                        "parent " + e.getKey() + " observed with " + e.getValue()
                                                + " split-children (expected 0 or 2)");
                                return;
                            }
                        }
                    } catch (RuntimeException concurrentModificationOrSimilar) {
                        violation.compareAndSet(null,
                                "reader threw " + concurrentModificationOrSimilar.getClass().getSimpleName()
                                        + " snapshotting the live shard list during a concurrent split");
                        return;
                    }
                }
            });
            reader.start();

            for (int i = 0; i < 2000 && violation.get() == null; i++) {
                KinesisShard open = stream.getShards().stream()
                        .filter(s -> !s.isClosed())
                        .max(java.util.Comparator.comparing(s ->
                                new java.math.BigInteger(s.getHashKeyRange().endingHashKey())
                                        .subtract(new java.math.BigInteger(s.getHashKeyRange().startingHashKey()))))
                        .orElseThrow();
                java.math.BigInteger start = new java.math.BigInteger(open.getHashKeyRange().startingHashKey());
                java.math.BigInteger end = new java.math.BigInteger(open.getHashKeyRange().endingHashKey());
                java.math.BigInteger mid = start.add(end).divide(java.math.BigInteger.TWO);
                if (mid.compareTo(start) <= 0 || mid.compareTo(end) >= 0) {
                    break;
                }
                kinesisService.splitShard(streamName, open.getShardId(), mid.toString(), REGION);
            }
            done.set(true);
            reader.join(TimeUnit.SECONDS.toMillis(10));
            assertFalse(reader.isAlive(), "reader thread did not terminate (trial " + trial + ")");

            final int t = trial;
            assertNull(violation.get(), () -> "reshard consistency violation (trial " + t + "): " + violation.get());
        }
    }
}
