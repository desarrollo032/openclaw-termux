'use strict';

const os = require('os');
const fs = require('fs');
const path = require('path');

const wrapperPath = process.env._OA_WRAPPER_PATH || path.join(
  process.env.HOME || '',
  '.openclaw-android',
  'bin',
  'node',
);

try {
  if (wrapperPath && fs.existsSync(wrapperPath)) {
    Object.defineProperty(process, 'execPath', {
      value: wrapperPath,
      writable: true,
      configurable: true,
    });
  }
} catch (_) {}

if (process.env._OA_ORIG_LD_PRELOAD) {
  process.env.LD_PRELOAD = process.env._OA_ORIG_LD_PRELOAD;
  delete process.env._OA_ORIG_LD_PRELOAD;
}

const originalCpus = os.cpus;
os.cpus = function cpus() {
  try {
    const result = originalCpus.call(os);
    if (Array.isArray(result) && result.length > 0) return result;
  } catch (_) {}
  return [{ model: 'unknown', speed: 0, times: { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 } }];
};

function loopbackInterfaces() {
  return {
    lo: [{
      address: '127.0.0.1',
      netmask: '255.0.0.0',
      family: 'IPv4',
      mac: '00:00:00:00:00:00',
      internal: true,
      cidr: '127.0.0.1/8',
    }],
  };
}

function hasNonLoopback(interfaces) {
  try {
    return Object.values(interfaces).some((entries) =>
      Array.isArray(entries) && entries.some((entry) => entry && entry.internal === false),
    );
  } catch (_) {
    return false;
  }
}

const originalNetworkInterfaces = os.networkInterfaces;
os.networkInterfaces = function networkInterfaces() {
  let interfaces;
  try {
    interfaces = originalNetworkInterfaces.call(os);
  } catch (_) {
    interfaces = loopbackInterfaces();
  }
  if (!process.env.OPENCLAW_DISABLE_BONJOUR && !hasNonLoopback(interfaces)) {
    process.env.OPENCLAW_DISABLE_BONJOUR = '1';
  }
  return interfaces;
};

if (!fs.existsSync('/bin/sh')) {
  try {
    const childProcess = require('child_process');
    const termuxSh = path.join(process.env.PREFIX || '', 'bin', 'sh');
    if (fs.existsSync(termuxSh)) {
      const originalExec = childProcess.exec;
      const originalExecSync = childProcess.execSync;
      childProcess.exec = function exec(command, options, callback) {
        if (typeof options === 'function') {
          callback = options;
          options = {};
        }
        options = options || {};
        if (!options.shell) options.shell = termuxSh;
        return originalExec.call(childProcess, command, options, callback);
      };
      childProcess.execSync = function execSync(command, options) {
        options = options || {};
        if (!options.shell) options.shell = termuxSh;
        return originalExecSync.call(childProcess, command, options);
      };
    }
  } catch (_) {}
}

try {
  const dns = require('dns');
  let servers = ['8.8.8.8', '8.8.4.4'];
  try {
    const resolv = fs.readFileSync(path.join(process.env.PREFIX || '', 'etc', 'resolv.conf'), 'utf8');
    const parsed = resolv.match(/^nameserver\s+(.+)$/gm);
    if (parsed && parsed.length > 0) {
      servers = parsed.map((line) => line.replace(/^nameserver\s+/, '').trim());
    }
  } catch (_) {}
  try { dns.setServers(servers); } catch (_) {}

  const originalLookup = dns.lookup;
  dns.lookup = function lookup(hostname, options, callback) {
    if (typeof options === 'function') {
      callback = options;
      options = {};
    }
    const originalOptions = options;
    const opts = typeof options === 'number' ? { family: options } : (options || {});
    const wantAll = opts.all === true;
    const family = opts.family || 0;
    const resolve = (fam, cb) => (fam === 6 ? dns.resolve6 : dns.resolve4)(hostname, cb);
    const tryResolve = (fam) => {
      resolve(fam, (err, addresses) => {
        if (!err && addresses && addresses.length > 0) {
          const resFam = fam === 6 ? 6 : 4;
          if (wantAll) callback(null, addresses.map((address) => ({ address, family: resFam })));
          else callback(null, addresses[0], resFam);
        } else if (family === 0 && fam === 4) {
          tryResolve(6);
        } else {
          originalLookup.call(dns, hostname, originalOptions, callback);
        }
      });
    };
    tryResolve(family === 6 ? 6 : 4);
  };

  const originalPromiseLookup = dns.promises.lookup;
  dns.promises.lookup = async function lookup(hostname, options) {
    const opts = typeof options === 'number' ? { family: options } : (options || {});
    const wantAll = opts.all === true;
    const family = opts.family || 0;
    const resolve = (fam) => new Promise((res, rej) => {
      const fn = fam === 6 ? dns.resolve6 : dns.resolve4;
      fn(hostname, (err, addresses) => (err ? rej(err) : res(addresses)));
    });
    const tryResolve = async (fam) => {
      try {
        const addresses = await resolve(fam);
        if (addresses && addresses.length > 0) {
          const resFam = fam === 6 ? 6 : 4;
          if (wantAll) return addresses.map((address) => ({ address, family: resFam }));
          return { address: addresses[0], family: resFam };
        }
      } catch (_) {}
      if (family === 0 && fam === 4) return tryResolve(6);
      return originalPromiseLookup.call(dns.promises, hostname, options);
    };
    return tryResolve(family === 6 ? 6 : 4);
  };
} catch (_) {}
