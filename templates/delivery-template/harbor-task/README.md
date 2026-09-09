# <Task Title>

## Overview

<What the bug or task is, in a few sentences. Name the upstream source: repo,
PR number, base commit.>

## Skills Tested

- <the specific reasoning the task demands, not generic labels>

## Environment

- Base image: <image>
- Repository sealed at `base_commit`, git remote severed
- Resources: <n> CPUs, <n> GB
- Internet: disabled during the agent phase
- Working directory: `/app`

## Difficulty

<REQUIRED SECTION. Not the label, the reason. What will a competent attempt get
wrong? The most useful tasks have a tractable surface and an intractable core,
so say which is which.>

## Solution

<REQUIRED SECTION. What `solution/solve.sh` does and which files it touches. If
the patch is the upstream fix byte for byte, say so: that equality is what makes
the task's provenance auditable.>

## Verification

<REQUIRED SECTION. Which tests are graded, whether they are new or modified in
the PR, what the verifier restores before grading, and the collection floor.
State the floor and why it exists.>

## Relevant experience

<REQUIRED SECTION. Who would find this natural, and what transferable skill it
exercises.>
