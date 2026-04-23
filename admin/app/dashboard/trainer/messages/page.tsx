"use client";

import { useState, useEffect, useRef } from "react";
import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { trainerConversationApi, type SupportTicket, type TicketMessage } from "@/lib/api";
import { MessageSquare, Send, ChevronLeft } from "lucide-react";

function formatTime(iso: string) {
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}
function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString([], { month: "short", day: "numeric" });
}

// ─── Conversation list item ────────────────────────────────────────────────────

function ConvoItem({
  ticket,
  active,
  onClick,
}: {
  ticket: SupportTicket;
  active: boolean;
  onClick: () => void;
}) {
  const initials = ticket.user.fullName
    .split(" ")
    .map((w) => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <button
      onClick={onClick}
      className={`w-full text-left px-4 py-3.5 flex items-center gap-3 transition-colors border-b border-zinc-800/60 ${
        active ? "bg-[#F1C40F]/8 border-l-2 border-l-[#F1C40F]" : "hover:bg-zinc-800/40"
      }`}
    >
      {ticket.user.avatarUrl ? (
        <img src={ticket.user.avatarUrl} alt={ticket.user.fullName} className="w-9 h-9 rounded-full object-cover flex-shrink-0" />
      ) : (
        <div className="w-9 h-9 rounded-full bg-[#F1C40F]/15 flex items-center justify-center flex-shrink-0">
          <span className="text-[#F1C40F] font-bold text-xs">{initials}</span>
        </div>
      )}
      <div className="min-w-0 flex-1">
        <p className={`text-sm font-semibold truncate ${active ? "text-white" : "text-zinc-200"}`}>
          {ticket.user.fullName}
        </p>
        <p className="text-xs text-zinc-500 truncate">{ticket.user.email}</p>
      </div>
      <span className="text-[10px] text-zinc-600 flex-shrink-0">{formatDate(ticket.updatedAt)}</span>
    </button>
  );
}

// ─── Chat bubble ───────────────────────────────────────────────────────────────

function ChatBubble({ msg, isMe }: { msg: TicketMessage; isMe: boolean }) {
  return (
    <div className={`flex gap-2 ${isMe ? "flex-row-reverse" : "flex-row"}`}>
      {!isMe && (
        <div className="w-7 h-7 rounded-full bg-zinc-700 flex items-center justify-center flex-shrink-0 mt-1">
          {msg.sender.avatarUrl ? (
            <img src={msg.sender.avatarUrl} className="w-7 h-7 rounded-full object-cover" alt="" />
          ) : (
            <span className="text-zinc-300 text-[10px] font-bold">
              {msg.sender.fullName.split(" ").map((w) => w[0]).join("").slice(0, 2).toUpperCase()}
            </span>
          )}
        </div>
      )}
      <div className={`max-w-[72%] ${isMe ? "items-end" : "items-start"} flex flex-col gap-0.5`}>
        <div
          className={`px-4 py-2.5 rounded-2xl text-sm leading-relaxed ${
            isMe
              ? "bg-[#F1C40F] text-black rounded-br-sm"
              : "bg-zinc-800 text-zinc-100 rounded-bl-sm"
          }`}
        >
          {msg.body}
        </div>
        <span className="text-[10px] text-zinc-600 px-1">{formatTime(msg.createdAt)}</span>
      </div>
    </div>
  );
}

// ─── Thread panel ──────────────────────────────────────────────────────────────

function ThreadPanel({
  ticket,
  onBack,
}: {
  ticket: SupportTicket;
  onBack: () => void;
}) {
  const { token, user } = useAuthStore();
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState("");
  const bottomRef = useRef<HTMLDivElement>(null);

  const { data: thread } = useQuery({
    queryKey: ["trainer-thread", ticket.id],
    queryFn: () => trainerConversationApi.getThread(ticket.gymId, ticket.id, token!),
    enabled: !!token,
    refetchInterval: 10_000,
  });

  const replyMutation = useMutation({
    mutationFn: (body: string) =>
      trainerConversationApi.reply(ticket.gymId, ticket.id, body, token!),
    onSuccess: () => {
      setDraft("");
      queryClient.invalidateQueries({ queryKey: ["trainer-thread", ticket.id] });
      queryClient.invalidateQueries({ queryKey: ["trainer-conversations"] });
    },
  });

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [thread?.messages]);

  const messages = thread?.messages ?? [];

  function handleSend() {
    const trimmed = draft.trim();
    if (!trimmed || replyMutation.isPending) return;
    replyMutation.mutate(trimmed);
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-3 px-5 py-4 border-b border-zinc-800 flex-shrink-0">
        <button
          onClick={onBack}
          className="md:hidden text-zinc-400 hover:text-white transition-colors mr-1"
        >
          <ChevronLeft size={20} />
        </button>
        {ticket.user.avatarUrl ? (
          <img src={ticket.user.avatarUrl} alt={ticket.user.fullName} className="w-9 h-9 rounded-full object-cover" />
        ) : (
          <div className="w-9 h-9 rounded-full bg-[#F1C40F]/15 flex items-center justify-center">
            <span className="text-[#F1C40F] font-bold text-xs">
              {ticket.user.fullName.split(" ").map((w) => w[0]).join("").slice(0, 2).toUpperCase()}
            </span>
          </div>
        )}
        <div>
          <p className="font-semibold text-white text-sm">{ticket.user.fullName}</p>
          <p className="text-xs text-zinc-500">{ticket.user.email}</p>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3">
        {messages.length === 0 && (
          <p className="text-center text-zinc-600 text-sm mt-8">No messages yet. Start the conversation.</p>
        )}
        {messages.map((msg) => (
          <ChatBubble key={msg.id} msg={msg} isMe={msg.senderId === user?.id} />
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Reply box */}
      <div className="px-4 py-3 border-t border-zinc-800 flex gap-2 flex-shrink-0">
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && handleSend()}
          placeholder="Type a message…"
          className="flex-1 bg-zinc-800 text-white text-sm rounded-xl px-4 py-2.5 outline-none placeholder-zinc-500 border border-zinc-700 focus:border-[#F1C40F]/40 transition-colors"
        />
        <button
          onClick={handleSend}
          disabled={!draft.trim() || replyMutation.isPending}
          className="w-10 h-10 bg-[#F1C40F] hover:bg-[#F1C40F]/90 disabled:opacity-40 rounded-xl flex items-center justify-center transition-colors flex-shrink-0"
        >
          <Send size={16} className="text-black" />
        </button>
      </div>
    </div>
  );
}

// ─── Page ──────────────────────────────────────────────────────────────────────

export default function TrainerMessagesPage() {
  const { token } = useAuthStore();
  const [selected, setSelected] = useState<SupportTicket | null>(null);

  const { data: convos, isLoading } = useQuery({
    queryKey: ["trainer-conversations"],
    queryFn: () => trainerConversationApi.listConversations(token!),
    enabled: !!token,
    refetchInterval: 30_000,
  });

  return (
    <div className="h-[calc(100vh-80px)] flex flex-col">
      <div className="mb-5">
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <MessageSquare size={22} className="text-[#F1C40F]" />
          Member Messages
        </h1>
        <p className="text-zinc-400 mt-1 text-sm">Direct conversations with your assigned members</p>
      </div>

      <div className="flex-1 flex min-h-0 rounded-xl overflow-hidden border border-zinc-800 bg-[#121721]">
        {/* Sidebar */}
        <div
          className={`w-full md:w-72 flex-shrink-0 border-r border-zinc-800 overflow-y-auto flex flex-col ${
            selected ? "hidden md:flex" : "flex"
          }`}
        >
          <div className="px-4 py-3 border-b border-zinc-800">
            <p className="text-xs font-black uppercase tracking-widest text-zinc-500">
              Conversations
              {convos && convos.length > 0 && (
                <span className="ml-2 text-zinc-400">({convos.length})</span>
              )}
            </p>
          </div>

          {isLoading ? (
            <div className="p-6 text-center text-zinc-500 text-sm">Loading…</div>
          ) : !convos?.length ? (
            <div className="p-8 text-center">
              <MessageSquare size={28} className="text-zinc-700 mx-auto mb-2" />
              <p className="text-zinc-500 text-sm">No conversations yet.</p>
              <p className="text-zinc-600 text-xs mt-1">Members initiate chats from the mobile app.</p>
            </div>
          ) : (
            convos.map((c) => (
              <ConvoItem
                key={c.id}
                ticket={c}
                active={selected?.id === c.id}
                onClick={() => setSelected(c)}
              />
            ))
          )}
        </div>

        {/* Thread */}
        <div className={`flex-1 flex flex-col min-w-0 ${selected ? "flex" : "hidden md:flex"}`}>
          {selected ? (
            <ThreadPanel ticket={selected} onBack={() => setSelected(null)} />
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center gap-3 text-center p-8">
              <MessageSquare size={36} className="text-zinc-700" />
              <p className="text-zinc-400 font-medium">Select a conversation</p>
              <p className="text-zinc-600 text-sm">Choose a member from the list to view the chat thread.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
