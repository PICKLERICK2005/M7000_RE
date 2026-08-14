#!/usr/bin/env node
// Read-only Marvell FBF layout inspector and SquashFS carver.

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

const [imagePath, outputPath] = process.argv.slice(2);
if (!imagePath) {
  throw new Error("Usage: fbf-extract.mjs IMAGE [SQUASHFS-OUTPUT]");
}

const image = readFileSync(imagePath);
if (image.subarray(0, 11).toString("ascii") !== "Marvell_FBF") {
  throw new Error("Input does not begin with Marvell_FBF");
}

const squashfsOffset = image.indexOf(Buffer.from("hsqs"));
if (squashfsOffset < 0) throw new Error("Little-endian SquashFS not found");
const bytesUsed = Number(image.readBigUInt64LE(squashfsOffset + 40));
if (bytesUsed <= 0 || squashfsOffset + bytesUsed > image.length) {
  throw new Error("Invalid SquashFS bytes_used value");
}

const rootfs = image.subarray(squashfsOffset, squashfsOffset + bytesUsed);
const sha256 = (data) => createHash("sha256").update(data).digest("hex");
const result = {
  format: "Marvell_FBF",
  image: {
    path: imagePath,
    size: image.length,
    sha256: sha256(image),
  },
  rootfs: {
    offset: squashfsOffset,
    offset_hex: `0x${squashfsOffset.toString(16)}`,
    size: bytesUsed,
    sha256: sha256(rootfs),
    filesystem: "SquashFS 4.0",
    compression_id: image.readUInt16LE(squashfsOffset + 20),
    block_size: image.readUInt32LE(squashfsOffset + 12),
    inode_count: image.readUInt32LE(squashfsOffset + 4),
  },
};

if (outputPath) {
  writeFileSync(outputPath, rootfs);
  result.rootfs.output = outputPath;
}
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
