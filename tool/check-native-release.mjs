import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isIP } from 'node:net';

export function checkNativeRelease(root, platform, configPath) {
  const issues = [];
  if (!['android', 'windows', 'ios'].includes(platform)) {
    return ['请选择 android、windows 或 ios。'];
  }
  let config;
  try {
    config = JSON.parse(readFileSync(resolve(root, configPath), 'utf8').replace(/^\uFEFF/, ''));
  } catch {
    return ['正式环境配置不存在或不是有效 JSON；没有读取或覆盖现有测试配置。'];
  }
  const allowed = ['APP_ENVIRONMENT', 'SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY'];
  if (!config || Array.isArray(config) || typeof config !== 'object') {
    return ['正式环境配置必须为 JSON 对象。'];
  }
  if (Object.keys(config).some((key) => !allowed.includes(key))) {
    issues.push('配置只允许环境标记、服务地址和客户端公开密钥；请移除其他字段。');
  }
  if (config.APP_ENVIRONMENT !== 'production') issues.push('必须明确指定 APP_ENVIRONMENT=production。');
  try {
    const url = new URL(config.SUPABASE_URL);
    const hostname = url.hostname.replace(/\.$/, '');
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash ||
        isIP(hostname.replace(/^\[|\]$/g, '')) || !hostname.includes('.') ||
        /(^|\.)(localhost|local|invalid|example|test)$/.test(hostname)) {
      issues.push('正式服务须使用 HTTPS 域名，不含账号、查询参数或本地/示例地址。');
    }
    if (hostname === 'eeeeisvdrcvjgmjtobgp.supabase.co') {
      issues.push('当前新加坡 Free 联调项目不能作为本项目的正式发行环境。');
    }
  } catch {
    issues.push('请填写有效的正式服务地址。');
  }
  const key = config.SUPABASE_PUBLISHABLE_KEY;
  let publicKey = typeof key === 'string' && /^sb_publishable_[A-Za-z0-9_-]+$/.test(key);
  if (typeof key === 'string' && key.split('.').length === 3) {
    try {
      publicKey = JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString()).role === 'anon';
    } catch { /* Reject malformed keys without printing their contents. */ }
  }
  if (!publicKey) issues.push('仅接受 publishable key 或 anon 角色 JWT，不能使用管理密钥。');
  if (platform === 'android') {
    try {
      const properties = readFileSync(resolve(root, 'android/key.properties'), 'utf8');
      const values = {};
      for (const line of properties.split(/\r?\n/)) {
        const match = line.match(/^\s*(storeFile|storePassword|keyAlias|keyPassword)\s*[=:]\s*(.+?)\s*$/);
        if (match) values[match[1]] = match[2];
      }
      if (['storeFile', 'storePassword', 'keyAlias', 'keyPassword'].some((key) => !values[key])) {
        issues.push('正式 Android 签名配置缺少必要字段。');
      } else {
        const storeFile = values.storeFile.replace(/\\([\\: ])/g, '$1');
        if (!existsSync(resolve(root, 'android/app', storeFile))) issues.push('正式 Android 签名文件不存在。');
        if (values.keyAlias.toLowerCase() === 'androiddebugkey') issues.push('不能将 Android debug 密钥别名用于正式发行。');
      }
    } catch {
      issues.push('缺少 android/key.properties；不会创建密钥或回退 debug 签名。');
    }
  }
  return issues;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [platform, configPath = 'config.release.local.json'] = process.argv.slice(2);
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const issues = checkNativeRelease(root, platform, configPath);
  for (const issue of issues) console.error(`- ${issue}`);
  if (issues.length) process.exitCode = 1;
  else console.log('配置预检通过；尚未验证服务可用性、正式签名有效性、设备或商店准入。');
}
