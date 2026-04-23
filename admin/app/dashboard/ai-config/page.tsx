"use client";

import { useState, useEffect } from "react";
import { Bot, Check, AlertCircle, RefreshCw, Zap, BarChart3 } from "lucide-react";
import { useRouter } from "next/navigation";
import { CustomSelect } from "@/components/ui/Select";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { platformApi, type AIProvider, type AIConfig } from "@/lib/api";
import { PageHeader } from "@/components/ui/PageHeader";

const AI_PROVIDERS: { value: AIProvider; label: string; description: string; recommended?: boolean }[] = [
  { value: "DEEPSEEK", label: "DeepSeek", description: "Cost-effective, high-quality AI", recommended: true },
  { value: "OPENAI", label: "OpenAI", description: "GPT-4 Turbo, GPT-3.5" },
  { value: "ANTHROPIC", label: "Anthropic", description: "Claude 3 Sonnet, Claude 3 Opus" },
  { value: "GOOGLE_GEMINI", label: "Google Gemini", description: "Gemini Pro, Gemini Ultra" },
  { value: "AZURE_OPENAI", label: "Azure OpenAI", description: "Azure-hosted OpenAI models" },
];

export default function AIConfigPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const [testingProvider, setTestingProvider] = useState<AIProvider | null>(null);
  const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null);

  const { data: config, isLoading, error } = useQuery({
    queryKey: ["ai-config"],
    queryFn: () => platformApi.getAIConfig(token!),
    enabled: !!token && isSuperAdmin(user?.role),
  });

  const { data: usage } = useQuery({
    queryKey: ["ai-usage"],
    queryFn: () => platformApi.getAIUsage(token!),
    enabled: !!token && isSuperAdmin(user?.role),
  });

  const updateMutation = useMutation({
    mutationFn: (data: Partial<AIConfig>) => platformApi.updateAIConfig(data, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["ai-config"] });
    },
  });

  const testMutation = useMutation({
    mutationFn: (provider: AIProvider) => platformApi.testAIConnection(provider, token!),
    onSuccess: (data) => {
      setTestResult({ success: true, message: data.message });
      setTestingProvider(null);
    },
    onError: (error: Error) => {
      setTestResult({ success: false, message: error.message });
      setTestingProvider(null);
    },
  });

  // Redirect if not super admin
  useEffect(() => {
    if (user && !isSuperAdmin(user?.role)) {
      router.push("/dashboard");
    }
  }, [user, router]);

  if (!isSuperAdmin(user?.role)) {
    return null;
  }

  const handleProviderChange = (provider: AIProvider) => {
    updateMutation.mutate({ activeProvider: provider });
  };

  const handleTestConnection = (provider: AIProvider) => {
    setTestingProvider(provider);
    setTestResult(null);
    testMutation.mutate(provider);
  };

  const handleFieldUpdate = (field: keyof AIConfig, value: string | number | boolean) => {
    // Prevent saving if the user accidentally blurs a masked field
    if (typeof value === "string") {
      const isMasked = /^[\u2022\u002A]{4,}/.test(value);
      if (isMasked) return;
    }
    updateMutation.mutate({ [field]: value });
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-4 text-red-400">
        Failed to load AI configuration
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="AI Configuration"
        description="Configure AI providers and settings for the platform"
        icon={<Bot size={24} />}
        actions={
          <div className="flex items-center gap-2">
            <span className={`px-3 py-1 rounded-full text-xs font-medium ${
              config?.isEnabled
                ? "bg-green-500/10 text-green-400"
                : "bg-red-500/10 text-red-400"
            }`}>
              {config?.isEnabled ? "AI Enabled" : "AI Disabled"}
            </span>
            <button
              onClick={() => handleFieldUpdate("isEnabled", !config?.isEnabled)}
              className="px-4 py-2 bg-[#F1C40F]/10 text-[#F1C40F] rounded-lg hover:bg-[#F1C40F]/20 transition-colors shrink-0"
            >
              {config?.isEnabled ? "Disable" : "Enable"}
            </button>
          </div>
        }
      />

      {/* Usage Stats */}
      {usage && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <BarChart3 size={20} className="text-[#F1C40F]" />
            AI Usage Statistics
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Total Requests</p>
              <p className="text-2xl font-bold text-white">{usage.totalRequests.toLocaleString()}</p>
            </div>
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Total Tokens</p>
              <p className="text-2xl font-bold text-white">{usage.totalTokens.toLocaleString()}</p>
            </div>
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Prompt Tokens</p>
              <p className="text-2xl font-bold text-white">{usage.promptTokens.toLocaleString()}</p>
            </div>
            <div className="bg-zinc-800/50 rounded-lg p-4">
              <p className="text-sm text-zinc-400">Est. Cost</p>
              <p className="text-2xl font-bold text-[#F1C40F]">${usage.estimatedCost}</p>
            </div>
          </div>
        </div>
      )}

      {/* Provider Selection */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
        <h2 className="text-lg font-semibold text-white mb-4">Active Provider</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
          {AI_PROVIDERS.map((provider) => (
            <button
              key={provider.value}
              onClick={() => handleProviderChange(provider.value)}
              className={`p-4 rounded-lg border-2 text-left transition-all relative ${
                config?.activeProvider === provider.value
                  ? "border-[#F1C40F] bg-[#F1C40F]/10"
                  : provider.recommended
                  ? "border-green-500/50 hover:border-green-500"
                  : "border-zinc-700 hover:border-zinc-600"
              }`}
            >
              {provider.recommended && (
                <span className="absolute -top-2 -right-2 px-2 py-0.5 bg-green-500 text-black text-xs font-bold rounded-full">
                  Best Value
                </span>
              )}
              <div className="flex items-center justify-between mb-2">
                <span className="font-medium text-white">{provider.label}</span>
                {config?.activeProvider === provider.value && (
                  <Check className="text-[#F1C40F]" size={20} />
                )}
              </div>
              <p className="text-sm text-zinc-400">{provider.description}</p>
            </button>
          ))}
        </div>
      </div>

      {/* Test Result */}
      {testResult && (
        <div className={`p-4 rounded-lg border ${
          testResult.success
            ? "bg-green-500/10 border-green-500/50 text-green-400"
            : "bg-red-500/10 border-red-500/50 text-red-400"
        }`}>
          <div className="flex items-center gap-2">
            {testResult.success ? <Check size={20} /> : <AlertCircle size={20} />}
            {testResult.message}
          </div>
        </div>
      )}

      {/* Provider Configurations */}
      <div className="space-y-4">
        {/* OpenAI */}
        {config?.activeProvider === "OPENAI" && (
          <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-white">OpenAI Configuration</h3>
              <button
                onClick={() => handleTestConnection("OPENAI")}
                disabled={testingProvider === "OPENAI"}
                className="px-4 py-2 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                {testingProvider === "OPENAI" ? (
                  <RefreshCw className="animate-spin" size={16} />
                ) : (
                  <Zap size={16} />
                )}
                Test Connection
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-zinc-400 mb-2">API Key</label>
                <input
                  type="password"
                  defaultValue={config?.openaiApiKey || ""}
                  onBlur={(e) => {
                    const val = e.target.value;
                    if (val && !/^[\u2022\u002A]{4,}/.test(val) && val !== config?.openaiApiKey) {
                      handleFieldUpdate("openaiApiKey", val);
                    }
                  }}
                  placeholder="sk-..."
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
                />
              </div>
              <CustomSelect
                label="Model"
                value={config?.openaiModel || "gpt-4-turbo"}
                onChange={(value) => handleFieldUpdate("openaiModel", value)}
                options={[
                  { value: "gpt-4-turbo", label: "GPT-4 Turbo" },
                  { value: "gpt-4", label: "GPT-4" },
                  { value: "gpt-3.5-turbo", label: "GPT-3.5 Turbo" },
                ]}
              />
              <div>
                <label className="block text-sm text-zinc-400 mb-2">Organization ID (Optional)</label>
                <input
                  type="text"
                  defaultValue={config?.openaiOrgId || ""}
                  onBlur={(e) => handleFieldUpdate("openaiOrgId", e.target.value)}
                  placeholder="org-..."
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
                />
              </div>
            </div>
          </div>
        )}

        {/* Anthropic */}
        {config?.activeProvider === "ANTHROPIC" && (
          <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-white">Anthropic Configuration</h3>
              <button
                onClick={() => handleTestConnection("ANTHROPIC")}
                disabled={testingProvider === "ANTHROPIC"}
                className="px-4 py-2 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                {testingProvider === "ANTHROPIC" ? (
                  <RefreshCw className="animate-spin" size={16} />
                ) : (
                  <Zap size={16} />
                )}
                Test Connection
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-zinc-400 mb-2">API Key</label>
                <input
                  type="password"
                  defaultValue={config?.anthropicApiKey || ""}
                  onBlur={(e) => {
                    const val = e.target.value;
                    if (val && !/^[\u2022\u002A]{4,}/.test(val) && val !== config?.anthropicApiKey) {
                      handleFieldUpdate("anthropicApiKey", val);
                    }
                  }}
                  placeholder="sk-ant-..."
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
                />
              </div>
              <CustomSelect
                label="Model"
                value={config?.anthropicModel || "claude-3-sonnet-20240229"}
                onChange={(value) => handleFieldUpdate("anthropicModel", value)}
                options={[
                  { value: "claude-3-opus-20240229", label: "Claude 3 Opus" },
                  { value: "claude-3-sonnet-20240229", label: "Claude 3 Sonnet" },
                  { value: "claude-3-haiku-20240307", label: "Claude 3 Haiku" },
                ]}
              />
            </div>
          </div>
        )}

        {/* DeepSeek (Recommended) */}
        {config?.activeProvider === "DEEPSEEK" && (
          <div className="bg-[#121721] border border-green-500/30 rounded-xl p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <h3 className="text-lg font-semibold text-white">DeepSeek Configuration</h3>
                <span className="px-2 py-0.5 bg-green-500/10 text-green-400 text-xs font-medium rounded-full">
                  Recommended
                </span>
              </div>
              <button
                onClick={() => handleTestConnection("DEEPSEEK")}
                disabled={testingProvider === "DEEPSEEK"}
                className="px-4 py-2 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                {testingProvider === "DEEPSEEK" ? (
                  <RefreshCw className="animate-spin" size={16} />
                ) : (
                  <Zap size={16} />
                )}
                Test Connection
              </button>
            </div>
            <p className="text-sm text-green-400/70 mb-4">
              DeepSeek offers high-quality AI at ~$0.14/million tokens - up to 50x cheaper than GPT-4
            </p>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm text-zinc-400 mb-2">
                  API Key
                  {config?.deepseekApiKey && config.deepseekApiKey.length > 0 && 
                   !config.deepseekApiKey.startsWith('••••••••') && 
                   config.deepseekApiKey.length < 35 && (
                    <span className="ml-2 text-xs text-yellow-500 flex items-center gap-1 inline-flex">
                      <AlertCircle size={12} />
                      Key usually 35+ chars
                    </span>
                  )}
                </label>
                <input
                  type="password"
                  defaultValue={config?.deepseekApiKey || ""}
                  onBlur={(e) => {
                    const val = e.target.value;
                    if (val && !/^[\u2022\u002A]{4,}/.test(val) && val !== config?.deepseekApiKey) {
                      handleFieldUpdate("deepseekApiKey", val);
                    }
                  }}
                  placeholder="sk-..."
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
                />
              </div>
              <CustomSelect
                label="Model"
                value={config?.deepseekModel || "deepseek-chat"}
                onChange={(value) => handleFieldUpdate("deepseekModel", value)}
                options={[
                  { value: "deepseek-chat", label: "DeepSeek Chat" },
                  { value: "deepseek-coder", label: "DeepSeek Coder" },
                  { value: "deepseek-reasoner", label: "DeepSeek Reasoner" },
                ]}
              />
              <div>
                <label className="block text-sm text-zinc-400 mb-2">Base URL</label>
                <input
                  type="text"
                  defaultValue={config?.deepseekBaseUrl || "https://api.deepseek.com"}
                  onBlur={(e) => handleFieldUpdate("deepseekBaseUrl", e.target.value)}
                  placeholder="https://api.deepseek.com"
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
                />
              </div>
            </div>
          </div>
        )}

        {/* Google Gemini */}
        {config?.activeProvider === "GOOGLE_GEMINI" && (
          <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-white">Google Gemini Configuration</h3>
              <button
                onClick={() => handleTestConnection("GOOGLE_GEMINI")}
                disabled={testingProvider === "GOOGLE_GEMINI"}
                className="px-4 py-2 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                {testingProvider === "GOOGLE_GEMINI" ? (
                  <RefreshCw className="animate-spin" size={16} />
                ) : (
                  <Zap size={16} />
                )}
                Test Connection
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-zinc-400 mb-2">API Key</label>
                <input
                  type="password"
                  defaultValue={config?.googleApiKey || ""}
                  onBlur={(e) => {
                    const val = e.target.value;
                    if (val && !/^[\u2022\u002A]{4,}/.test(val) && val !== config?.googleApiKey) {
                      handleFieldUpdate("googleApiKey", val);
                    }
                  }}
                  placeholder="AIza..."
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F]"
                />
              </div>
              <CustomSelect
                label="Model"
                value={config?.googleModel || "gemini-pro"}
                onChange={(value) => handleFieldUpdate("googleModel", value)}
                options={[
                  { value: "gemini-pro", label: "Gemini Pro" },
                  { value: "gemini-ultra", label: "Gemini Ultra" },
                ]}
              />
            </div>
          </div>
        )}

        {/* Global Settings */}
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">Global AI Settings</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-zinc-400 mb-2">Max Tokens Per Request</label>
              <input
                type="number"
                defaultValue={config?.maxTokensPerRequest || 4096}
                onBlur={(e) => handleFieldUpdate("maxTokensPerRequest", parseInt(e.target.value))}
                className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-[#F1C40F]"
              />
            </div>
            <div>
              <label className="block text-sm text-zinc-400 mb-2">Temperature (0-1)</label>
              <input
                type="number"
                step="0.1"
                min="0"
                max="1"
                defaultValue={config?.temperature || 0.7}
                onBlur={(e) => handleFieldUpdate("temperature", parseFloat(e.target.value))}
                className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-[#F1C40F]"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
