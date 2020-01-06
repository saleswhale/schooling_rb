# Redis commands

```redis
 XPENDING key group 
   [start end count] [consumer] 
 XCLAIM key group consumer min-idle-time ID 
   [ID ...] [IDLE ms] [TIME ms-unix-time] [RETRYCOUNT count] [FORCE] [JUSTID] 
 XADD key ID field value 
   [field value ...] 
 XREADGROUP GROUP group consumer STREAMS key [key ...] ID [ID ...] 
   [COUNT count] [BLOCK milliseconds] [NOACK]
 XACK key group ID [ID ...] 
 XGROUP 
   [CREATE key groupname id-or-$] 
   [SETID key groupname id-or-$] 
   [DESTROY key groupname] 
   [DELCONSUMER key groupname consumername] 
```
