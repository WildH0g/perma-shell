#!/bin/bash

# free_memory_only.sh
# A script to strictly free up cached RAM and clear swap space (if used).
# Run this script with sudo privileges: sudo ./free_memory_only.sh

# --- Safety Check ---
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Please use 'sudo ./free_memory_only.sh'"
  exit 1
fi

set -euo pipefail # Exit immediately if a command exits with a non-zero status,
                  # if an unset variable is used, or if a command in a pipeline fails.

echo "--- Starting Memory Optimization ---"

# --- Initial Memory Snapshot ---
echo -e "\n--- Initial Memory Usage ---"
echo "Current RAM and Swap usage:"
free -h
echo "------------------------------"

INITIAL_MEM_FREE_KB=$(free -k | awk '/Mem:/ {print $4}')
INITIAL_SWAP_USED_KB=$(free -k | awk '/Swap:/ {print $3}')

# --- Step 1: Dropping Filesystem Caches ---
echo -e "\n--- Step 1: Dropping Filesystem Caches ---"
echo "Attempting to free up cached memory by dropping clean filesystem caches..."
# Ensure all buffered data is written to disk before dropping caches.
sync
# Drop clean caches (pagecache).
echo 1 > /proc/sys/vm/drop_caches
echo "Pagecache dropped."

# Drop dentries and inodes.
echo 2 > /proc/sys/vm/drop_caches
echo "Dentries and inodes dropped."

# Drop all caches (pagecache, dentries, and inodes).
# This is the most effective for freeing cached RAM.
echo 3 > /proc/sys/vm/drop_caches
echo "All filesystem caches dropped."

CURRENT_MEM_FREE_KB=$(free -k | awk '/Mem:/ {print $4}')
FREED_MEM_CACHES_KB=$((CURRENT_MEM_FREE_KB - INITIAL_MEM_FREE_KB))
echo "Memory freed from caches: $(numfmt --to=iec-i --suffix=B $((FREED_MEM_CACHES_KB * 1024)))"
echo "Current memory usage after cache drop:"
free -h

# --- Step 2: Clearing Swap Space ---
echo -e "\n--- Step 2: Clearing Swap Space ---"
SWAP_USED_BEFORE_CLEAR_KB=$(free -k | awk '/Swap:/ {print $3}')

if [ "$SWAP_USED_BEFORE_CLEAR_KB" -gt 0 ]; then
    echo "Swap space is in use. Deactivating and reactivating swap..."
    # Turn off all swap areas, then turn them back on.
    # This forces data from swap back into RAM if there's enough space,
    # effectively clearing the swap file/partition.
    swapoff -a && swapon -a
    echo "Swap cleared."
    SWAP_USED_AFTER_CLEAR_KB=$(free -k | awk '/Swap:/ {print $3}')
    FREED_SWAP_KB=$((SWAP_USED_BEFORE_CLEAR_KB - SWAP_USED_AFTER_CLEAR_KB))
    echo "Swap space reclaimed: $(numfmt --to=iec-i --suffix=B $((FREED_SWAP_KB * 1024)))"
else
    echo "Swap space is not currently in use. No need to clear swap."
fi
echo "Current memory usage after swap check:"
free -h

# --- Final Summary ---
echo -e "\n--- Memory Optimization Complete ---"
echo "Final RAM and Swap usage:"
free -h

FINAL_MEM_FREE_KB=$(free -k | awk '/Mem:/ {print $4}')
TOTAL_MEM_RECLAIMED_KB=$((FINAL_MEM_FREE_KB - INITIAL_MEM_FREE_KB))
TOTAL_SWAP_CLEARED_KB=$((INITIAL_SWAP_USED_KB - $(free -k | awk '/Swap:/ {print $3}')))

echo "-------------------------------------"
echo "Total RAM freed (primarily caches): $(numfmt --to=iec-i --suffix=B $((TOTAL_MEM_RECLAIMED_KB * 1024)))"
echo "Total Swap cleared: $(numfmt --to=iec-i --suffix=B $((TOTAL_SWAP_CLEARED_KB * 1024)))"
echo "-------------------------------------"

echo -e "\nNote: Clearing caches might temporarily slow down subsequent access to recently used files."
echo "Done."
