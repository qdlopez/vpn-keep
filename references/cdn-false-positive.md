# CDN 假通节点问题

## 现象
TCP 握手成功（延迟 < 100ms），但通过代理访问 Google 返回 HTTP 000/超时。

## 原因
大量免费节点指向 Cloudflare CDN IP，TCP 连接秒回（CF 边缘节点就在附近），但实际不转发任何代理流量。

## 实测数据（v4.3 测试）
```
解析 189 个节点, 去重后 37 个
TCP 测速通过: 22 个

候选#0: ger-nnn.prostosetup.org:443 (628ms) vless -> ❌ HTTP 000
候选#1: 178.215.238.148:8443 (630ms) vless -> ❌ HTTP 000
候选#2: 90.156.254.164:19562 (751ms) vless -> ❌ HTTP 000
候选#3: cf4.danfeng.eu.org:2053 (63ms) vless  -> ❌ HTTP 000  ← 延迟最低但仍假通
候选#4: 121.180.225.222:19530 (132ms) vless -> ❌ HTTP 000
候选#5: 121.180.225.222:16000 (134ms) vless -> ❌ HTTP 000
候选#6: r1.mizulina.top:22231 (195ms) vless -> ✅ HTTP 200 🎉
```

前 6 个全部假通，第 7 个才成功。说明：
1. **TCP 延迟和代理可用性无相关性**
2. **必须用 Google HTTP 200 作为唯一验证标准**
3. **单候选验证命中率低**，需要多候选重试

## 对策
- v4.3 改为多候选逐一试（最多 15 个）
- 协议优先级排序：vless Reality > vless TLS > vless 普通 > vmess > ss
  - Reality 节点不经过 CDN，命中率更高
  - ws 节点大量经过 CDN，假通率高
