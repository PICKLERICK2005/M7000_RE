#!/usr/bin/env node
// Read-only firmware signature, entropy, and printable-string scanner.

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

const signatures = {
  elf: Buffer.from([0x7f, 0x45, 0x4c, 0x46]),
  gzip: Buffer.from([0x1f, 0x8b, 0x08]),
  xz: Buffer.from([0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00]),
  bzip2: Buffer.from("BZh"),
  zip: Buffer.from([0x50, 0x4b, 0x03, 0x04]),
  squashfs_le: Buffer.from("hsqs"),
  squashfs_be: Buffer.from("sqsh"),
  ubi: Buffer.from("UBI#"),
  ubifs: Buffer.from([0x31, 0x18, 0x10, 0x06]),
  jffs2_le: Buffer.from([0x85, 0x19]),
  jffs2_be: Buffer.from([0x19, 0x85]),
  cramfs_le: Buffer.from([0x45, 0x3d, 0xcd, 0x28]),
  cramfs_be: Buffer.from([0x28, 0xcd, 0x3d, 0x45]),
  uimage: Buffer.from([0x27, 0x05, 0x19, 0x56]),
  dtb: Buffer.from([0xd0, 0x0d, 0xfe, 0xed]),
  cpio_newc: Buffer.from("070701"),
  cpio_crc: Buffer.from("070702"),
  marvell_fbf: Buffer.from("Marvell_FBF"),
};

function findOffsets(data, needle) {
  const results = [];
  let offset = 0;
  while ((offset = data.indexOf(needle, offset)) !== -1) {
    results.push(offset);
    offset += 1;
  }
  return results;
}

function entropy(data) {
  if (!data.length) return 0;
  const counts = new Uint32Array(256);
  for (const value of data) counts[value] += 1;
  let result = 0;
  for (const count of counts) {
    if (count) {
      const probability = count / data.length;
      result -= probability * Math.log2(probability);
    }
  }
  return result;
}

function printableStrings(data, minimum) {
  const results = [];
  let start = null;
  for (let index = 0; index <= data.length; index += 1) {
    const value = index < data.length ? data[index] : 0;
    if ((value >= 0x20 && value <= 0x7e) || value === 0x09) {
      if (start === null) start = index;
    } else if (start !== null) {
      if (index - start >= minimum) {
        results.push({ offset: start, text: data.subarray(start, index).toString("ascii") });
      }
      start = null;
    }
  }
  return results;
}

function parseArguments(argv) {
  const options = { blockSize: 0x10000, stringMinimum: 8, output: null, image: null };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--block-size") options.blockSize = Number(argv[++index]);
    else if (argument === "--string-minimum") options.stringMinimum = Number(argv[++index]);
    else if (argument === "--output") options.output = argv[++index];
    else if (!options.image) options.image = argument;
    else throw new Error(`Unexpected argument: ${argument}`);
  }
  if (!options.image) throw new Error("Usage: firmware-scan.mjs IMAGE [--output FILE]");
  return options;
}

const options = parseArguments(process.argv.slice(2));
const data = readFileSync(options.image);
const blocks = [];
for (let offset = 0; offset < data.length; offset += options.blockSize) {
  const block = data.subarray(offset, offset + options.blockSize);
  blocks.push({ offset, size: block.length, entropy: Number(entropy(block).toFixed(6)) });
}
const foundSignatures = {};
for (const [name, signature] of Object.entries(signatures)) {
  const found = findOffsets(data, signature);
  if (found.length) foundSignatures[name] = found;
}
const result = {
  path: options.image,
  size: data.length,
  sha256: createHash("sha256").update(data).digest("hex"),
  signatures: foundSignatures,
  entropy: {
    block_size: options.blockSize,
    minimum: Math.min(...blocks.map((item) => item.entropy)),
    maximum: Math.max(...blocks.map((item) => item.entropy)),
    average: Number((blocks.reduce((sum, item) => sum + item.entropy, 0) / blocks.length).toFixed(6)),
    blocks,
  },
  strings: printableStrings(data, options.stringMinimum),
};
const rendered = `${JSON.stringify(result, null, 2)}\n`;
if (options.output) writeFileSync(options.output, rendered);
else process.stdout.write(rendered);
