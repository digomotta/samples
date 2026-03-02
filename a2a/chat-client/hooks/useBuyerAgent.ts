import { useCallback, useRef, useState } from "react";
import { buyerAgentConfig } from "../config";
import type { BuyerAgentEvent } from "../types";

interface UseBuyerAgentOptions {
  onEvent: (event: BuyerAgentEvent) => void;
}

export function useBuyerAgent({ onEvent }: UseBuyerAgentOptions) {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const eventSourceRef = useRef<EventSource | null>(null);

  const startSession = useCallback(
    async (goal?: string) => {
      const resp = await fetch(`${buyerAgentConfig.baseUrl}/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          goal: goal || buyerAgentConfig.defaultGoal,
          seller_url: buyerAgentConfig.defaultSellerUrl,
        }),
      });
      const data = await resp.json();
      const sid = data.session_id;
      setSessionId(sid);
      setIsRunning(true);
      setIsPaused(false);

      // Open SSE connection
      const es = new EventSource(
        `${buyerAgentConfig.baseUrl}/events/${sid}`,
      );
      eventSourceRef.current = es;

      const handleEvent = (e: MessageEvent) => {
        const event: BuyerAgentEvent = JSON.parse(e.data);
        onEvent(event);
      };

      es.addEventListener("buyer_message", handleEvent);
      es.addEventListener("seller_response", handleEvent);
      es.addEventListener("human_intervention", handleEvent);
      es.addEventListener("status", handleEvent);
      es.addEventListener("error", handleEvent);

      es.onerror = () => {
        // SSE connection closed (session ended)
        es.close();
        eventSourceRef.current = null;
        setIsRunning(false);
        setIsPaused(false);
        setSessionId(null);
      };
    },
    [onEvent],
  );

  const intervene = useCallback(
    async (message: string) => {
      if (!sessionId) return;
      await fetch(`${buyerAgentConfig.baseUrl}/intervene/${sessionId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message }),
      });
    },
    [sessionId],
  );

  const pause = useCallback(async () => {
    if (!sessionId) return;
    await fetch(`${buyerAgentConfig.baseUrl}/pause/${sessionId}`, {
      method: "POST",
    });
    setIsPaused(true);
  }, [sessionId]);

  const resume = useCallback(async () => {
    if (!sessionId) return;
    await fetch(`${buyerAgentConfig.baseUrl}/resume/${sessionId}`, {
      method: "POST",
    });
    setIsPaused(false);
  }, [sessionId]);

  const stop = useCallback(() => {
    if (eventSourceRef.current) {
      eventSourceRef.current.close();
      eventSourceRef.current = null;
    }
    setIsRunning(false);
    setIsPaused(false);
    setSessionId(null);
  }, []);

  return { startSession, intervene, pause, resume, stop, isRunning, isPaused, sessionId };
}
