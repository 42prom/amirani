"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { ToastProvider } from "@/components/ui/Toast";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000,
            refetchOnWindowFocus: false,
            retry: (failureCount, error: any) => { // eslint-disable-line @typescript-eslint/no-explicit-any
              // Retry up to 5 times for transient backend errors (502, 503, 504)
              if (failureCount < 5 && [502, 503, 504].includes(error?.response?.status)) {
                return true;
              }
              return failureCount < 2; // Default retry for other errors
            },
            retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000),
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      <ToastProvider>{children}</ToastProvider>
    </QueryClientProvider>
  );
}
