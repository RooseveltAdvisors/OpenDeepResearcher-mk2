class SimpleRateLimiter {
  private requests: Map<string, { count: number; reset: number }> = new Map();
  private readonly maxLimit = 100; // requests per window
  private readonly timeWindow = 60 * 1000; // 1 minute in milliseconds

  async rateLimit(identifier: string) {
    const now = Date.now();
    const userRequests = this.requests.get(identifier);

    if (!userRequests || userRequests.reset < now) {
      // Reset or create new window
      this.requests.set(identifier, {
        count: 1,
        reset: now + this.timeWindow,
      });
      return {
        success: true,
        limit: this.maxLimit,
        remaining: this.maxLimit - 1,
        reset: now + this.timeWindow,
      };
    }

    if (userRequests.count >= this.maxLimit) {
      return {
        success: false,
        limit: this.maxLimit,
        remaining: 0,
        reset: userRequests.reset,
      };
    }

    userRequests.count += 1;
    return {
      success: true,
      limit: this.maxLimit,
      remaining: this.maxLimit - userRequests.count,
      reset: userRequests.reset,
    };
  }
}

export const rateLimiter = new SimpleRateLimiter();
