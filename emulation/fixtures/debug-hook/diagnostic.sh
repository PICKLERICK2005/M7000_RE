#!/bin/sh
set -u
{
  echo '=== id ==='
  id
  echo '=== pwd ==='
  pwd
  echo '=== env ==='
  env | sort
  echo '=== mount ==='
  mount
  echo '=== ps ==='
  ps
  echo '=== directories ==='
  ls -la / /misc /cache /tmp /dev
  echo '=== writable synthetic paths ==='
  printf 'synthetic fixture\n' > /misc/hook-write-test
  printf 'synthetic fixture\n' > /cache/hook-write-test
  printf 'synthetic fixture\n' > /tmp/hook-write-test
  ls -l /misc/hook-write-test /cache/hook-write-test /tmp/hook-write-test
} > /traces/hook-context.txt
