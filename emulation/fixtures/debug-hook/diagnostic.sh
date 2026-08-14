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
} > /traces/hook-context.txt 2>&1
