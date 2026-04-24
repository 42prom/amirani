"use client";

import { useState, useEffect } from "react";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import {
  Mail,
  Plus,
  RefreshCw,
  Send,
  Clock,
  CheckCircle,
  XCircle,
  Copy,
  Check,
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import { api } from "@/lib/api";

interface Invitation {
  id: string;
  email: string;
  status: "PENDING" | "ACCEPTED" | "EXPIRED";
  inviteToken: string;
  expiresAt: string;
  createdAt: string;
  acceptedAt?: string;
}

export default function InvitationsPage() {
  const router = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();
  const [showModal, setShowModal] = useState(false);
  const [email, setEmail] = useState("");
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Redirect if not super admin
  useEffect(() => {
    if (user && !isSuperAdmin(user.role)) {
      router.push("/dashboard");
    }
  }, [user, router]);

  const { data: invitations, isLoading } = useQuery({
    queryKey: ["invitations"],
    queryFn: () => api<Invitation[]>("/admin/invitations", { token: token! }),
    enabled: !!token,
  });

  const createMutation = useMutation({
    mutationFn: (email: string) =>
      api<Invitation>("/admin/invitations", {
        method: "POST",
        body: { email },
        token: token!,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["invitations"] });
      setShowModal(false);
      setEmail("");
    },
  });

  const resendMutation = useMutation({
    mutationFn: (invitationId: string) =>
      api<Invitation>(`/admin/invitations/${invitationId}/resend`, {
        method: "POST",
        token: token!,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["invitations"] });
    },
  });

  const copyInviteLink = (invitation: Invitation) => {
    const link = `${window.location.origin}/register?token=${invitation.inviteToken}`;
    navigator.clipboard.writeText(link);
    setCopiedId(invitation.id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "ACCEPTED":
        return <CheckCircle className="text-green-400" size={16} />;
      case "EXPIRED":
        return <XCircle className="text-red-400" size={16} />;
      default:
        return <Clock className="text-yellow-400" size={16} />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "ACCEPTED":
        return "bg-green-500/10 text-green-400";
      case "EXPIRED":
        return "bg-red-500/10 text-red-400";
      default:
        return "bg-yellow-500/10 text-yellow-400";
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Gym Owner Invitations"
        description="Send invitation links to register new gym owners"
        icon={<Mail size={24} />}
        actions={
            <button
              onClick={() => setShowModal(true)}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
            >
              <Plus size={18} />
              Send Invitation
            </button>
        }
      />

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <p className="text-sm text-zinc-400">Pending</p>
          <p className="text-3xl font-bold text-yellow-400 mt-2">
            {invitations?.filter((i) => i.status === "PENDING").length || 0}
          </p>
        </div>
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <p className="text-sm text-zinc-400">Accepted</p>
          <p className="text-3xl font-bold text-green-400 mt-2">
            {invitations?.filter((i) => i.status === "ACCEPTED").length || 0}
          </p>
        </div>
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6">
          <p className="text-sm text-zinc-400">Expired</p>
          <p className="text-3xl font-bold text-red-400 mt-2">
            {invitations?.filter((i) => i.status === "EXPIRED").length || 0}
          </p>
        </div>
      </div>

      {/* Invitations List */}
      <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
        <div className="p-4 border-b border-zinc-800">
          <h2 className="text-lg font-semibold text-white">All Invitations</h2>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <RefreshCw className="animate-spin text-[#F1C40F]" size={24} />
          </div>
        ) : !invitations || invitations.length === 0 ? (
          <div className="text-center py-12">
            <Mail className="mx-auto text-zinc-600 mb-4" size={48} />
            <p className="text-zinc-400">No invitations sent yet</p>
            <button
              onClick={() => setShowModal(true)}
              className="mt-4 text-[#F1C40F] hover:underline"
            >
              Send your first invitation
            </button>
          </div>
        ) : (
          <div className="divide-y divide-zinc-800">
            {invitations.map((invitation) => (
              <div
                key={invitation.id}
                className="p-4 flex items-center justify-between"
              >
                <div className="flex items-center gap-4">
                  <div className="w-10 h-10 bg-zinc-800 rounded-full flex items-center justify-center">
                    <Mail className="text-zinc-400" size={18} />
                  </div>
                  <div>
                    <p className="font-medium text-white">{invitation.email}</p>
                    <p className="text-xs text-zinc-500">
                      Sent {new Date(invitation.createdAt).toLocaleDateString()}
                      {invitation.status === "PENDING" && (
                        <> · Expires {new Date(invitation.expiresAt).toLocaleDateString()}</>
                      )}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-4">
                  <span
                    className={`px-3 py-1 rounded-full text-xs font-medium flex items-center gap-1 ${getStatusColor(
                      invitation.status
                    )}`}
                  >
                    {getStatusIcon(invitation.status)}
                    {invitation.status}
                  </span>

                  {invitation.status === "PENDING" && (
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => copyInviteLink(invitation)}
                        className="p-2 hover:bg-zinc-800 rounded-lg transition-colors"
                        title="Copy invite link"
                      >
                        {copiedId === invitation.id ? (
                          <Check className="text-green-400" size={16} />
                        ) : (
                          <Copy className="text-zinc-400" size={16} />
                        )}
                      </button>
                      <button
                        onClick={() => resendMutation.mutate(invitation.id)}
                        disabled={resendMutation.isPending}
                        className="p-2 hover:bg-zinc-800 rounded-lg transition-colors"
                        title="Resend invitation"
                      >
                        <Send className="text-zinc-400" size={16} />
                      </button>
                    </div>
                  )}

                  {invitation.status === "EXPIRED" && (
                    <button
                      onClick={() => resendMutation.mutate(invitation.id)}
                      disabled={resendMutation.isPending}
                      className="px-3 py-1 bg-zinc-800 text-white text-sm rounded-lg hover:bg-zinc-700 transition-colors"
                    >
                      Resend
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Create Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 transition-all animate-in fade-in duration-300">
          <div className="flex flex-col bg-[#121721] border border-white/10 rounded-[2.5rem] w-full max-w-md max-h-[90vh] shadow-[0_0_100px_rgba(0,0,0,0.5)] overflow-hidden">
            {/* FIXED HEADER */}
            <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
              <div>
                <h2 className="text-xl font-black text-white uppercase tracking-tight italic flex items-center gap-2">
                  <Mail className="text-[#F1C40F]" size={24} />
                  Send Invitation
                </h2>
                <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mt-1">Initiate Gym Owner Protocol</p>
              </div>
              <button
                onClick={() => {
                  setShowModal(false);
                  setEmail("");
                }}
                className="p-2.5 hover:bg-white/5 rounded-xl text-zinc-500 hover:text-white transition-all border border-white/5"
              >
                <XCircle size={20} />
              </button>
            </div>

            {/* SCROLLABLE CONTENT */}
            <div className="flex-1 overflow-y-auto amirani-scrollbar p-8">
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  createMutation.mutate(email);
                }}
                className="space-y-6"
              >
                {createMutation.error && (
                  <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 text-red-400 text-xs font-bold uppercase tracking-widest flex items-center gap-3">
                    <XCircle size={18} />
                    {(createMutation.error as Error).message}
                  </div>
                )}

                <div>
                  <label className="amirani-label mb-3">
                    Email Address
                  </label>
                  <div className="relative group">
                    <Mail className="absolute left-4 text-zinc-500 group-focus-within:text-[#F1C40F] transition-colors" size={18} />
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      required
                      placeholder="gymowner@example.com"
                      className="amirani-input amirani-input-with-icon"
                    />
                  </div>
                </div>

                <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                  <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest leading-relaxed">
                    The gym owner will receive an encrypted membership invitation link via the specified electronic mail address.
                  </p>
                </div>
              </form>
            </div>

            {/* FIXED FOOTER */}
            <div className="p-8 border-t border-white/5 bg-white/[0.02] flex justify-end gap-3 shrink-0">
              <button
                type="button"
                onClick={() => {
                  setShowModal(false);
                  setEmail("");
                }}
                className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-all"
              >
                Cancel
              </button>
              <button
                onClick={() => createMutation.mutate(email)}
                disabled={createMutation.isPending || !email}
                className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all disabled:opacity-50 flex items-center justify-center gap-2 shadow-xl shadow-[#F1C40F]/20"
              >
                {createMutation.isPending ? (
                  <RefreshCw className="animate-spin" size={16} />
                ) : (
                  <Send size={16} />
                )}
                Send Protocol
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
