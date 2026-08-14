#!/usr/bin/env node
// Inspector for TP-Link ISP update envelopes; decryption exactly reproduces firmware 3.0.2.

import { createDecipheriv, createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

const [path, option, outputPath] = process.argv.slice(2);
if (!path || path === "--help" || ![undefined, "--json", "--decrypt"].includes(option) || (option === "--decrypt" && !outputPath)) {
  process.stderr.write("Usage: node tools/isp-inspect.mjs FILE [--json | --decrypt OUTPUT]\n");
  process.exit(path ? 2 : 0);
}
const raw = readFileSync(path);
const compact = raw.toString("ascii").replace(/\s+/g, "");
const canonicalBase64 = /^[A-Za-z0-9+/]*={0,2}$/.test(compact) && compact.length % 4 === 0;
let decoded = Buffer.alloc(0);
let roundTrips = false;
if (canonicalBase64) {
  decoded = Buffer.from(compact, "base64");
  roundTrips = decoded.toString("base64").replace(/=+$/, "") === compact.replace(/=+$/, "");
}
const salted = roundTrips && decoded.subarray(0, 8).toString("ascii") === "Salted__";
const result = {
  file: path,
  input_size: raw.length,
  input_sha256: createHash("sha256").update(raw).digest("hex"),
  encoding: roundTrips ? "Base64" : "unknown",
  decoded_size: roundTrips ? decoded.length : null,
  envelope: salted ? "OpenSSL salted ciphertext" : "unknown",
  magic: salted ? "Salted__" : null,
  salt_hex: salted && decoded.length >= 16 ? decoded.subarray(8, 16).toString("hex") : null,
  ciphertext_size: salted && decoded.length >= 16 ? decoded.length - 16 : null,
  cipher: "unknown",
  secret: "unknown",
  payload: salted ? "encrypted" : "unknown",
};
if (option === "--decrypt") {
  if (!salted) throw new Error("recognized OpenSSL salted envelope required for decryption");
  // Reproduces usr/bin/mbedtls_aes-128-ecb and libispupdate.so from firmware 3.0.2.
  const firmwarePassphrase = Buffer.from("3_eliboM_kniL-PT", "ascii");
  const key = createHash("md5").update(Buffer.concat([firmwarePassphrase, decoded.subarray(8, 16)])).digest();
  const decipher = createDecipheriv("aes-128-ecb", key, null);
  const cleartext = Buffer.concat([decipher.update(decoded.subarray(16)), decipher.final()]);
  writeFileSync(outputPath, cleartext);
  result.cipher = "AES-128-ECB";
  result.key_derivation = "MD5(passphrase || 8-byte salt), OpenSSL EVP_BytesToKey-compatible for one 16-byte block";
  result.secret = "firmware-embedded constant (not printed)";
  result.decrypted = { output: outputPath, size: cleartext.length, sha256: createHash("sha256").update(cleartext).digest("hex") };
}
if (option === "--json") process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
else {
  const rows = [["Encoding", result.encoding], ["Envelope", result.envelope], ["Magic", result.magic ?? "n/a"], ["Salt", result.salt_hex ?? "n/a"], ["Decoded size", result.decoded_size ?? "n/a"], ["Ciphertext size", result.ciphertext_size ?? "n/a"], ["Cipher", result.cipher], ["Secret", result.secret], ["Payload", result.payload], ["SHA-256", result.input_sha256]];
  for (const [key, value] of rows) process.stdout.write(`${key.padEnd(18)}${value}\n`);
  if (result.decrypted) process.stdout.write(`Output            ${result.decrypted.output}\nOutput size       ${result.decrypted.size}\nOutput SHA-256    ${result.decrypted.sha256}\n`);
}
