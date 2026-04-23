import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'standalone',
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "images.unsplash.com",
      },
      {
        protocol: "https",
        hostname: "amirani.esme.ge",
      },
      {
        protocol: "http",
        hostname: "localhost",
        port: "3085",
      },
    ],
  },

  // Proxy /api/* and /socket.io/* to the backend.
  // In Docker, INTERNAL_API_URL should be 'http://backend:3085'
  // In local development, it defaults to 'http://localhost:3085'
  async rewrites() {
    const apiTarget = process.env.INTERNAL_API_URL || "http://localhost:3085";
    return [
      {
        source: "/api/:path*",
        destination: `${apiTarget}/api/:path*`,
      },
      {
        source: "/socket.io/:path*",
        destination: `${apiTarget}/socket.io/:path*`,
      },
      {
        source: "/uploads/:path*",
        destination: `${apiTarget}/uploads/:path*`,
      },
    ];
  },
};

export default nextConfig;
