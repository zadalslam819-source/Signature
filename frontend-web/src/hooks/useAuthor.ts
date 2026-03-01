import { type NostrEvent, type NostrMetadata, NSchema as n } from '@nostrify/nostrify';
import { useNostr } from '@nostrify/react';
import { useQuery } from '@tanstack/react-query';
import { eventCache, CACHE_TTL } from '@/lib/eventCache';
import { debugLog } from '@/lib/debug';

/**
 * Parse profile event content into metadata
 */
function parseProfileMetadata(event: NostrEvent): { event: NostrEvent; metadata?: NostrMetadata } {
  try {
    const metadata = n.json().pipe(n.metadata()).parse(event.content);
    return { metadata, event };
  } catch {
    return { event };
  }
}

export function useAuthor(pubkey: string | undefined) {
  const { nostr } = useNostr();

  return useQuery<{ event?: NostrEvent; metadata?: NostrMetadata }>({
    queryKey: ['author', pubkey ?? ''],

    queryFn: async ({ signal }) => {
      if (!pubkey) {
        return {};
      }

      debugLog(`[useAuthor] Fetching profile for ${pubkey.slice(0, 8)}...`);

      // Query for profile events and take the newest one
      // 15s timeout to accommodate slow relay connections
      const events = await nostr.query(
        [{ kinds: [0], authors: [pubkey!], limit: 5 }],
        { signal: AbortSignal.any([signal, AbortSignal.timeout(15000)]) },
      );

      if (events.length === 0) {
        debugLog(`[useAuthor] No profile found for ${pubkey.slice(0, 8)}...`);
        // Return empty but don't throw - this allows other sources to provide data
        return {};
      }

      // Take the most recent event (kind 0 is replaceable)
      const event = events.sort((a, b) => b.created_at - a.created_at)[0];

      debugLog(`[useAuthor] Found profile for ${pubkey.slice(0, 8)}...`);

      // Also add to event cache for future synchronous access
      eventCache.event(event).catch(() => {
        // Silently ignore cache errors
      });

      return parseProfileMetadata(event);
    },

    retry: 3,          // Retry 3 times on failure (WebSocket can be flaky)
    retryDelay: 1000,  // 1 second between retries
    staleTime: CACHE_TTL.PROFILE,
    gcTime: CACHE_TTL.PROFILE * 6,
    refetchOnWindowFocus: true,
  });
}
