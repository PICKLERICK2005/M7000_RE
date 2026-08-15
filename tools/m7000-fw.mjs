#!/usr/bin/env node
// Offline inspector, verifier, and component extractor for M7000 Marvell_FBF images.

import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";

const compressionNames = { 1: "gzip", 2: "lzma", 3: "lzo", 4: "xz", 5: "lz4", 6: "zstd" };
const signatures = [
  ["device-tree", Buffer.from([0xd0, 0x0d, 0xfe, 0xed])],
  ["gzip", Buffer.from([0x1f, 0x8b, 0x08])],
  ["ELF", Buffer.from([0x7f, 0x45, 0x4c, 0x46])],
];

function usage(message) {
  if (message) process.stderr.write(`Error: ${message}\n\n`);
  process.stderr.write("Usage:\n  node tools/m7000-fw.mjs info IMAGE [--json]\n  node tools/m7000-fw.mjs verify IMAGE [--json]\n  node tools/m7000-fw.mjs extract IMAGE OUTPUT_DIR [--json]\n");
  process.exit(message ? 2 : 0);
}

function sha256(data) {
  return createHash("sha256").update(data).digest("hex");
}

function findAll(data, needle) {
  const offsets = [];
  for (let offset = 0; (offset = data.indexOf(needle, offset)) >= 0; offset += 1) offsets.push(offset);
  return offsets;
}

function align(value, boundary) {
  return Math.ceil(value / boundary) * boundary;
}

function parseFbfComponents(data, errors) {
  const descriptorOffset = 0x140;
  const descriptorSize = 52;
  const descriptorCount = 10;
  const payloadAlignment = 0x2000;
  if (data.length < descriptorOffset + descriptorSize * descriptorCount) {
    errors.push("truncated FBF component table");
    return [];
  }

  let payloadOffset = payloadAlignment;
  const components = [];
  for (let index = 0; index < descriptorCount; index += 1) {
    const offset = descriptorOffset + index * descriptorSize;
    const rawId = data.subarray(offset, offset + 4).toString("ascii");
    const numericId = [...rawId].reverse().join("");
    const size = data.readUInt32LE(offset + 24);
    const component = { index, raw_id: rawId, numeric_id: numericId, size };
    if (size > 0) {
      component.offset = payloadOffset;
      component.offset_hex = `0x${payloadOffset.toString(16)}`;
      component.end = payloadOffset + size;
      if (component.end > data.length) {
        errors.push(`component ${rawId} exceeds image boundary`);
      } else {
        component.sha256 = sha256(data.subarray(component.offset, component.end));
      }
      payloadOffset = align(component.end, payloadAlignment);
    }
    components.push(component);
  }
  return components;
}

function inspect(path) {
  const data = readFileSync(path);
  const errors = [];
  const warnings = [];
  if (data.length < 96) errors.push("image is too small to contain an FBF header");
  const magic = data.subarray(0, 11).toString("ascii");
  if (magic !== "Marvell_FBF") errors.push(`unrecognized container magic ${JSON.stringify(magic)}`);

  const rootfsOffset = data.indexOf(Buffer.from("hsqs"));
  const components = parseFbfComponents(data, errors);
  let rootfs = null;
  if (rootfsOffset < 0) {
    errors.push("SquashFS little-endian magic not found");
  } else if (rootfsOffset + 96 > data.length) {
    errors.push("truncated SquashFS superblock");
  } else {
    const sizeBig = data.readBigUInt64LE(rootfsOffset + 40);
    if (sizeBig > BigInt(Number.MAX_SAFE_INTEGER)) {
      errors.push("SquashFS bytes_used exceeds safe integer range");
    } else {
      const size = Number(sizeBig);
      const end = rootfsOffset + size;
      if (size < 96) errors.push("invalid SquashFS bytes_used");
      else if (end > data.length) errors.push(`truncated SquashFS: needs ${end} bytes, image has ${data.length}`);
      else {
        const payload = data.subarray(rootfsOffset, end);
        const major = data.readUInt16LE(rootfsOffset + 28);
        const minor = data.readUInt16LE(rootfsOffset + 30);
        rootfs = {
          offset: rootfsOffset,
          offset_hex: `0x${rootfsOffset.toString(16)}`,
          end,
          size,
          sha256: sha256(payload),
          filesystem: `SquashFS ${major}.${minor}`,
          compression_id: data.readUInt16LE(rootfsOffset + 20),
          compression: compressionNames[data.readUInt16LE(rootfsOffset + 20)] ?? "unknown",
          block_size: data.readUInt32LE(rootfsOffset + 12),
          inode_count: data.readUInt32LE(rootfsOffset + 4),
        };
        if (major !== 4) warnings.push(`unexpected SquashFS major version ${major}`);
      }
    }
  }

  const detected = [];
  for (const [type, signature] of signatures) {
    for (const offset of findAll(data, signature)) {
      if (!rootfs || offset < rootfs.offset || offset >= rootfs.end) detected.push({ type, offset, offset_hex: `0x${offset.toString(16)}` });
    }
  }
  const elf = detected.find((item) => item.type === "ELF" && item.offset + 20 <= data.length);
  let architecture = "unknown";
  if (elf) {
    const littleEndian = data[elf.offset + 5] === 1;
    const machine = littleEndian ? data.readUInt16LE(elf.offset + 18) : data.readUInt16BE(elf.offset + 18);
    if (machine === 40) architecture = `ARM ${littleEndian ? "little" : "big"}-endian`;
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
    container: magic === "Marvell_FBF" ? "Marvell_FBF" : "unknown",
    image: { path, filename: basename(path), size: data.length, sha256: sha256(data) },
    rootfs,
    components,
    architecture,
    detected_sections: detected,
    authenticity: "not assessed; no cryptographic signature scheme has been identified",
    _data: data,
  };
}

function publicResult(result) {
  const { _data, ...safe } = result;
  return safe;
}

function printHuman(result, verb) {
  const rows = [
    ["Container", result.container], ["Image size", String(result.image.size)],
    ["SHA-256", result.image.sha256], ["Architecture", result.architecture],
  ];
  if (result.rootfs) rows.push(
    ["RootFS offset", result.rootfs.offset_hex], ["RootFS size", String(result.rootfs.size)],
    ["Filesystem", result.rootfs.filesystem], ["Compression", result.rootfs.compression],
    ["RootFS SHA-256", result.rootfs.sha256],
  );
  process.stdout.write(`TP-Link M7000 Firmware ${verb}\n${"-".repeat(48)}\n`);
  for (const [key, value] of rows) process.stdout.write(`${key.padEnd(18)}${value}\n`);
  process.stdout.write(`Validation        ${result.valid ? "PASS" : "FAIL"}\n`);
  for (const warning of result.warnings) process.stdout.write(`Warning           ${warning}\n`);
  for (const error of result.errors) process.stdout.write(`Error             ${error}\n`);
}

const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) usage();
const json = args.includes("--json");
const positional = args.filter((item) => item !== "--json");
const [command, imagePath, outputDir] = positional;
if (!command || !imagePath || !["info", "verify", "extract"].includes(command)) usage("invalid command or missing image");
if (command === "extract" && !outputDir) usage("extract requires OUTPUT_DIR");

let result;
try {
  result = inspect(imagePath);
} catch (error) {
  process.stderr.write(`Error: ${error.message}\n`);
  process.exit(2);
}

if (command === "extract" && result.valid) {
  mkdirSync(outputDir, { recursive: true });
  const report = publicResult(result);
  report.extracted = [];
  for (const component of result.components.filter((item) => item.size > 0)) {
    const outputName = `${String(component.index).padStart(2, "0")}-${component.numeric_id}.bin`;
    const outputPath = join(outputDir, outputName);
    writeFileSync(outputPath, result._data.subarray(component.offset, component.end));
    report.extracted.push({ path: outputPath, raw_id: component.raw_id, numeric_id: component.numeric_id, size: component.size, sha256: component.sha256 });
  }
  writeFileSync(join(outputDir, "manifest.json"), `${JSON.stringify(report, null, 2)}\n`);
  if (json) process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  else {
    printHuman(result, "Extractor");
    process.stdout.write(`Components        ${report.extracted.length}\nManifest          ${join(outputDir, "manifest.json")}\n`);
  }
} else {
  if (json) process.stdout.write(`${JSON.stringify(publicResult(result), null, 2)}\n`);
  else printHuman(result, command === "verify" ? "Verifier" : "Inspector");
}
if (!result.valid) process.exit(1);
