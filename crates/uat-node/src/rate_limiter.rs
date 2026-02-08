// Rate Limiter Module - DDoS Protection
// Implements Token Bucket Algorithm dengan IP-based tracking

use std::collections::HashMap;
use std::net::IpAddr;
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::{Duration, Instant};

/// Recover from poisoned mutex instead of panicking
fn safe_lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    match mutex.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// Token Bucket Rate Limiter
/// Allows burst traffic but limits average rate over time
#[derive(Clone)]
pub struct RateLimiter {
    buckets: Arc<Mutex<HashMap<IpAddr, TokenBucket>>>,
    max_tokens: u32,           // Maximum tokens (burst capacity)
    refill_rate: u32,          // Tokens per second
    cleanup_interval: Duration, // How often to cleanup old entries
    last_cleanup: Arc<Mutex<Instant>>,
}

struct TokenBucket {
    tokens: f64,
    last_refill: Instant,
}

impl RateLimiter {
    /// Create new rate limiter
    /// 
    /// # Arguments
    /// * `requests_per_second` - Maximum average requests per second
    /// * `burst_size` - Maximum burst size (if None, uses 2x requests_per_second)
    pub fn new(requests_per_second: u32, burst_size: Option<u32>) -> Self {
        let max_tokens = burst_size.unwrap_or(requests_per_second * 2);
        
        RateLimiter {
            buckets: Arc::new(Mutex::new(HashMap::new())),
            max_tokens,
            refill_rate: requests_per_second,
            cleanup_interval: Duration::from_secs(300), // 5 minutes
            last_cleanup: Arc::new(Mutex::new(Instant::now())),
        }
    }

    /// Check if request is allowed for given IP
    /// Returns true if request can proceed, false if rate limit exceeded
    pub fn check_rate_limit(&self, ip: IpAddr) -> bool {
        // Periodic cleanup
        self.cleanup_if_needed();

        let mut buckets = safe_lock(&self.buckets);
        
        let bucket = buckets.entry(ip).or_insert_with(|| TokenBucket {
            tokens: self.max_tokens as f64,
            last_refill: Instant::now(),
        });

        // Refill tokens based on elapsed time
        let now = Instant::now();
        let elapsed = now.duration_since(bucket.last_refill).as_secs_f64();
        let tokens_to_add = elapsed * self.refill_rate as f64;
        
        bucket.tokens = (bucket.tokens + tokens_to_add).min(self.max_tokens as f64);
        bucket.last_refill = now;

        // Check if we have at least 1 token
        if bucket.tokens >= 1.0 {
            bucket.tokens -= 1.0;
            true
        } else {
            false
        }
    }

    /// Get current token count for IP (for monitoring)
    #[allow(dead_code)]
    pub fn get_tokens(&self, ip: IpAddr) -> Option<f64> {
        let buckets = safe_lock(&self.buckets);
        buckets.get(&ip).map(|b| b.tokens)
    }

    /// Get number of tracked IPs
    #[allow(dead_code)]
    pub fn tracked_ips(&self) -> usize {
        safe_lock(&self.buckets).len()
    }

    /// Cleanup old entries (IPs that haven't made requests recently)
    fn cleanup_if_needed(&self) {
        let mut last_cleanup = safe_lock(&self.last_cleanup);
        
        if last_cleanup.elapsed() >= self.cleanup_interval {
            let mut buckets = safe_lock(&self.buckets);
            let now = Instant::now();
            
            // Remove buckets idle for > 10 minutes
            buckets.retain(|_, bucket| {
                now.duration_since(bucket.last_refill) < Duration::from_secs(600)
            });
            
            *last_cleanup = now;
        }
    }

    /// Reset rate limit for specific IP (admin tool)
    #[allow(dead_code)]
    pub fn reset_ip(&self, ip: IpAddr) {
        let mut buckets = safe_lock(&self.buckets);
        buckets.remove(&ip);
    }

    /// Clear all rate limits (admin tool)
    #[allow(dead_code)]
    pub fn reset_all(&self) {
        let mut buckets = safe_lock(&self.buckets);
        buckets.clear();
    }
}

/// Warp filter for rate limiting
pub mod filters {
    use super::RateLimiter;
    use std::net::IpAddr;
    use warp::Filter;

    /// Extract client IP from request
    pub fn client_ip() -> impl Filter<Extract = (IpAddr,), Error = std::convert::Infallible> + Clone {
        warp::addr::remote()
            .map(|addr: Option<std::net::SocketAddr>| {
                addr.map(|a| a.ip())
                    .unwrap_or_else(|| IpAddr::from([127, 0, 0, 1]))
            })
    }

    /// Rate limit filter
    pub fn rate_limit(
        limiter: RateLimiter,
    ) -> impl Filter<Extract = (), Error = warp::Rejection> + Clone {
        client_ip()
            .and(warp::any().map(move || limiter.clone()))
            .and_then(|ip: IpAddr, limiter: RateLimiter| async move {
                if limiter.check_rate_limit(ip) {
                    Ok(())
                } else {
                    Err(warp::reject::custom(RateLimitExceeded { ip }))
                }
            })
            .untuple_one()
    }

    /// Rate limit exceeded rejection
    #[derive(Debug)]
    pub struct RateLimitExceeded {
        pub ip: IpAddr,
    }

    impl warp::reject::Reject for RateLimitExceeded {}
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::{IpAddr, Ipv4Addr};
    use std::thread;

    #[test]
    fn test_rate_limiter_allows_burst() {
        let limiter = RateLimiter::new(10, Some(20)); // 10 req/sec, burst 20
        let ip = IpAddr::V4(Ipv4Addr::new(192, 168, 1, 1));

        // Should allow burst of 20 requests
        for i in 0..20 {
            assert!(limiter.check_rate_limit(ip), "Request {} should be allowed", i);
        }

        // 21st request should be blocked
        assert!(!limiter.check_rate_limit(ip), "Request 21 should be blocked");
    }

    #[test]
    fn test_rate_limiter_refills() {
        let limiter = RateLimiter::new(10, Some(10)); // 10 req/sec, burst 10
        let ip = IpAddr::V4(Ipv4Addr::new(192, 168, 1, 2));

        // Exhaust tokens
        for _ in 0..10 {
            assert!(limiter.check_rate_limit(ip));
        }
        assert!(!limiter.check_rate_limit(ip)); // Should be blocked

        // Wait 1 second for refill (10 tokens)
        thread::sleep(Duration::from_secs(1));

        // Should allow 10 more requests
        for i in 0..10 {
            assert!(limiter.check_rate_limit(ip), "Refilled request {} should be allowed", i);
        }
    }

    #[test]
    fn test_rate_limiter_different_ips() {
        let limiter = RateLimiter::new(5, Some(5));
        let ip1 = IpAddr::V4(Ipv4Addr::new(192, 168, 1, 10));
        let ip2 = IpAddr::V4(Ipv4Addr::new(192, 168, 1, 20));

        // Exhaust ip1
        for _ in 0..5 {
            assert!(limiter.check_rate_limit(ip1));
        }
        assert!(!limiter.check_rate_limit(ip1));

        // ip2 should still work (separate bucket)
        for i in 0..5 {
            assert!(limiter.check_rate_limit(ip2), "IP2 request {} should be allowed", i);
        }
    }

    #[test]
    fn test_get_tokens() {
        let limiter = RateLimiter::new(10, Some(10));
        let ip = IpAddr::V4(Ipv4Addr::new(192, 168, 1, 30));

        // Initial tokens should be max (10)
        assert!(limiter.check_rate_limit(ip));
        let tokens = limiter.get_tokens(ip).unwrap();
        assert!(tokens >= 8.9 && tokens <= 9.1, "Tokens should be ~9 after 1 request");

        // Consume 5 more
        for _ in 0..5 {
            limiter.check_rate_limit(ip);
        }
        let tokens = limiter.get_tokens(ip).unwrap();
        assert!(tokens >= 3.9 && tokens <= 4.1, "Tokens should be ~4 after 6 requests");
    }

    #[test]
    fn test_reset_ip() {
        let limiter = RateLimiter::new(5, Some(5));
        let ip = IpAddr::V4(Ipv4Addr::new(192, 168, 1, 40));

        // Exhaust tokens
        for _ in 0..5 {
            limiter.check_rate_limit(ip);
        }
        assert!(!limiter.check_rate_limit(ip)); // Blocked

        // Reset
        limiter.reset_ip(ip);

        // Should work again
        assert!(limiter.check_rate_limit(ip), "Should work after reset");
    }

    #[test]
    fn test_tracked_ips_count() {
        let limiter = RateLimiter::new(10, Some(10));
        
        assert_eq!(limiter.tracked_ips(), 0);

        let ip1 = IpAddr::V4(Ipv4Addr::new(10, 0, 0, 1));
        let ip2 = IpAddr::V4(Ipv4Addr::new(10, 0, 0, 2));
        let ip3 = IpAddr::V4(Ipv4Addr::new(10, 0, 0, 3));

        limiter.check_rate_limit(ip1);
        assert_eq!(limiter.tracked_ips(), 1);

        limiter.check_rate_limit(ip2);
        assert_eq!(limiter.tracked_ips(), 2);

        limiter.check_rate_limit(ip3);
        assert_eq!(limiter.tracked_ips(), 3);
    }
}
