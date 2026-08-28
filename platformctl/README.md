# platformctl

Initial commands:

```bash
platformctl doctor
platformctl net dns example.com
platformctl net tcp example.com 443
platformctl net route 1.1.1.1
platformctl net mtu 1.1.1.1
platformctl net diagnose example.com --port 443
platformctl tls inspect example.com --port 443
platformctl docker report
platformctl incident collect --host 1.1.1.1 --port 443
```

Do not add destructive remediation commands until authorization, logging and approval behaviour are designed.
