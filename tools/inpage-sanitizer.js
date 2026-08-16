/* In-page sanitizer used for the read-only physical validation.
 *
 * Published so the sanitization claim in docs/readonly-validation-result.md is
 * auditable: this is the exact policy that decided what was retained.
 *
 * Deny by default. Values survive only for the allowlisted, non-identifying
 * enums the static model makes predictions about. Everything else is reduced to
 * type, length and character class before it leaves the page.
 */
(function () {
  if (window.__obs) return 'already-installed';

  // Values retained ONLY for fields the static model predicts. Deny by default.
  var VALUE_OK = {
    result: 1, factoryDefault: 1,
    connectStatus: 1, registerStatus: 1, networkType: 1, signalStrength: 1,
    simStatus: 1, roamingStatus: 1, roamingEnable: 1, roaming: 1,
    dataSwitch: 1, enableDataSwitch: 1, netSelMode: 1,
    networkSelectionStatus: 1, callFailReason: 1,
    preferredNetworkMode: 1, selectedNetworkMode: 1, networkSelectionMode: 1,
    networkPreferredMode: 1, dataSwitchStatus: 1, cardType: 1,
    activeProfile: 1, defaultProfile: 1, maxProfileNum: 1,
    ipv4ApnType: 1, ipv6ApnType: 1, ipv4AuthType: 1, ipv6AuthType: 1, pdpType: 1,
    profileID: 1, isp_need_local_update: 1,
    unreadMessages: 1, number: 1, charging: 1, connected: 1, enable: 1,
    status: 1, invalidPassword: 1, limitation: 1, isLimit: 1, bandType: 1,
    mode: 1, channel: 1, region: 1
  };
  // Anchored so it cannot swallow legitimate fields: an earlier revision used a
  // bare /sign/ and redacted signalStrength, which is a prediction field.
  var HARD = /passw|pwd|token|cookie|session|stok|secret|credential|signature|(^|_)keys?($|_)|(^|_)auth/i;

  function numClass(n) {
    if (!isFinite(n)) return 'nonfinite';
    if (n === 0) return '0';
    if (n === Math.floor(n)) {
      var a = Math.abs(n);
      if (a < 10) return 'int<10';
      if (a < 100) return 'int<100';
      if (a < 100000) return 'int<1e5';
      return 'int>=1e5';
    }
    return 'float';
  }

  function strShape(s) {
    var cls;
    if (!s.length) cls = 'empty';
    else if (/^[0-9]+$/.test(s)) cls = 'digits';
    else if (/^[0-9a-fA-F]+$/.test(s)) cls = 'hexdigits';
    else if (/^[\x20-\x7e]*$/.test(s)) cls = 'ascii-printable';
    else cls = 'non-ascii';
    var o = { type: 'string', len: s.length, charclass: cls, value_retained: false };
    // PLMN falsification probe: BCD model predicts decimal-only. Record only
    // the boolean, never the digits.
    if (cls === 'hexdigits' && /[a-fA-F]/.test(s)) o.contains_hex_af = true;
    return o;
  }

  function san(v, key) {
    key = key || '';
    if (key && HARD.test(key)) return { type: typeof v, redacted: 'hard' };
    if (v === null) return { type: 'null' };
    if (v instanceof Array) {
      return { type: 'array', len: v.length, element: v.length ? san(v[0], key + '[]') : null };
    }
    if (typeof v === 'object') {
      var o = { type: 'object', fields: {} }, ks = Object.keys(v).sort();
      for (var i = 0; i < ks.length; i++) o.fields[ks[i]] = san(v[ks[i]], ks[i]);
      return o;
    }
    if (typeof v === 'boolean') return { type: 'boolean', value: v };
    if (typeof v === 'number') {
      return VALUE_OK[key] ? { type: 'number', value: v }
                           : { type: 'number', cls: numClass(v), value_retained: false };
    }
    if (typeof v === 'string') {
      if (VALUE_OK[key] && /^[0-9]{1,3}$/.test(v)) return { type: 'string', value: v };
      return strShape(v);
    }
    return { type: typeof v };
  }

  window.__obs = { samples: [], label: 'init', installed: Date.now() };

  // Passive tap: the SPA JSON.parses each decrypted response. We observe the
  // parsed object, sanitize, and drop the reference. We never alter it.
  var origParse = JSON.parse;
  JSON.parse = function (text, reviver) {
    var out = origParse.call(JSON, text, reviver);
    try {
      if (out && typeof out === 'object' && !(out instanceof Array) &&
          Object.prototype.hasOwnProperty.call(out, 'result')) {
        window.__obs.samples.push({
          t: Date.now(),
          label: window.__obs.label,
          top_keys: Object.keys(out).sort(),
          schema: san(out)
        });
        if (window.__obs.samples.length > 400) window.__obs.samples.shift();
      }
    } catch (e) { /* never break the app */ }
    return out;
  };
  window.__obs.uninstall = function () { JSON.parse = origParse; return 'removed'; };

  return 'installed';
})();
