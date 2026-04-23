"use client";

import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { trainerApi, type TrainerWorkoutPlan, type TrainerDietPlan } from "@/lib/api";
import {
  ArrowLeft, Dumbbell, ClipboardList, ChevronRight,
  User, Weight, Ruler, Calendar, Activity, Target, Globe, Scale, BarChart2
} from "lucide-react";
import { uploadApi } from "@/lib/api";
import Link from "next/link";
import Image from "next/image";
import { use, useState, useEffect } from "react";

function calcAge(dob: string | null): string | null {
  if (!dob) return null;
  const diff = Date.now() - new Date(dob).getTime();
  return `${Math.floor(diff / 3.156e10)} years old`;
}

function calcBmi(weightKg: string | number | null, heightCm: number | null): number | null {
  const w = weightKg ? parseFloat(String(weightKg)) : null;
  const h = heightCm ? heightCm / 100 : null;
  if (!w || !h || h <= 0) return null;
  return Math.round((w / (h * h)) * 10) / 10;
}

function bmiCategory(bmi: number): { label: string; color: string } {
  if (bmi < 18.5) return { label: 'Underweight', color: 'text-blue-400' };
  if (bmi < 25)   return { label: 'Normal',      color: 'text-green-400' };
  if (bmi < 30)   return { label: 'Overweight',  color: 'text-yellow-400' };
  return             { label: 'Obese',        color: 'text-red-400' };
}

function PlanCard({
  plan,
  memberId,
  type,
}: {
  plan: TrainerWorkoutPlan | TrainerDietPlan;
  memberId: string;
  type: "workout" | "diet";
}) {
  const isWorkout = type === "workout";
  const href = `/dashboard/trainer/members/${memberId}/${type}?planId=${plan.id}`;
  const isAI = plan.isAIGenerated;

  return (
    <Link
      href={href}
      className="block bg-zinc-900/50 border border-zinc-800 rounded-xl p-4 hover:border-zinc-600 transition-colors group"
    >
      <div className="flex items-start justify-between">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            {plan.isActive && (
              <span className="px-1.5 py-0.5 bg-green-500/15 text-green-400 text-[9px] font-black uppercase tracking-wider rounded">
                Active
              </span>
            )}
            {isAI && (
              <span className="px-1.5 py-0.5 bg-blue-500/15 text-blue-400 text-[9px] font-black uppercase tracking-wider rounded">
                AI
              </span>
            )}
            {!isAI && (
              <span className="px-1.5 py-0.5 bg-[#F1C40F]/15 text-[#F1C40F] text-[9px] font-black uppercase tracking-wider rounded">
                Trainer
              </span>
            )}
          </div>
          <p className="font-semibold text-white text-sm truncate">{plan.name}</p>
          {isWorkout ? (
            <p className="text-xs text-zinc-500 mt-0.5">
              {(plan as TrainerWorkoutPlan).difficulty} ·{" "}
              {(plan as TrainerWorkoutPlan).routines.length} days
            </p>
          ) : (
            <p className="text-xs text-zinc-500 mt-0.5">
              {(plan as TrainerDietPlan).targetCalories} kcal ·{" "}
              P {(plan as TrainerDietPlan).targetProtein}g · C {(plan as TrainerDietPlan).targetCarbs}g · F {(plan as TrainerDietPlan).targetFats}g
            </p>
          )}
        </div>
        <ChevronRight size={16} className="text-zinc-600 group-hover:text-[#F1C40F] transition-colors mt-1 flex-shrink-0" />
      </div>
    </Link>
  );
}

export default function TrainerMemberDetailPage({
  params,
}: {
  params: Promise<{ memberId: string }>;
}) {
  const { memberId } = use(params);
  const { token } = useAuthStore();

  const { data: members } = useQuery({
    queryKey: ["trainer-members"],
    queryFn: () => trainerApi.getMembers(token!),
    enabled: !!token,
  });

  const member = members?.find((m) => m.user.id === memberId);

  const { data: workoutPlans, isLoading: wpLoading } = useQuery({
    queryKey: ["trainer-workout-plans", memberId],
    queryFn: () => trainerApi.getMemberWorkoutPlans(memberId, token!),
    enabled: !!token && !!memberId,
  });

  const { data: dietPlans, isLoading: dpLoading } = useQuery({
    queryKey: ["trainer-diet-plans", memberId],
    queryFn: () => trainerApi.getMemberDietPlans(memberId, token!),
    enabled: !!token && !!memberId,
  });

  const user = member?.user;
  const age = user ? calcAge(user.dob) : null;
  const bmi = user ? calcBmi(user.weight, (user as any).heightCm) : null;
  const bmiInfo = bmi ? bmiCategory(bmi) : null;
  const qc = useQueryClient();

  const [unitPref, setUnitPrefLocal] = useState<'METRIC' | 'IMPERIAL'>('METRIC');
  const [langPref, setLangPrefLocal] = useState<'EN' | 'KA' | 'RU'>('EN');

  useEffect(() => {
    if ((user as any)?.unitPreference)    setUnitPrefLocal((user as any).unitPreference);
    if ((user as any)?.languagePreference) setLangPrefLocal((user as any).languagePreference);
  }, [(user as any)?.unitPreference, (user as any)?.languagePreference]);

  const updatePref = useMutation({
    mutationFn: (data: { unitPreference?: 'METRIC' | 'IMPERIAL'; languagePreference?: 'EN' | 'KA' | 'RU' }) =>
      trainerApi.updateMemberPreferences(memberId, data, token!),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['trainer-members'] }),
  });

  return (
    <div>
      {/* Back */}
      <Link
        href="/dashboard/trainer"
        className="inline-flex items-center gap-2 text-zinc-500 hover:text-white text-sm mb-6 transition-colors"
      >
        <ArrowLeft size={16} />
        Back to Members
      </Link>

      {/* Member profile */}
      {user && (
        <div className="bg-[#121721] border border-zinc-800 rounded-xl p-6 mb-6">
          <div className="flex flex-col md:flex-row gap-6">
            {/* Left: Basic Info & Avatar */}
            <div className="flex-1">
              <div className="flex items-center gap-4 mb-6">
                {user.avatarUrl ? (
                  <div className="relative w-20 h-20 rounded-full overflow-hidden ring-2 ring-zinc-800">
                    <Image 
                      src={uploadApi.getFullUrl(user.avatarUrl)} 
                      alt={user.fullName} 
                      fill
                      className="object-cover"
                      unoptimized={true}
                    />
                  </div>
                ) : (
                  <div className="w-20 h-20 rounded-full bg-[#F1C40F]/15 flex items-center justify-center flex-shrink-0 ring-2 ring-zinc-800">
                    <User size={32} className="text-[#F1C40F]" />
                  </div>
                )}
                <div>
                  <h1 className="text-2xl font-bold text-white tracking-tight">{user.fullName}</h1>
                  <p className="text-zinc-500 font-medium">{user.email}</p>
                  {age && <p className="text-xs text-[#F1C40F] mt-1 font-bold uppercase tracking-wider">{age}</p>}
                </div>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-8 gap-3">
                <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-xl p-3">
                  <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] uppercase font-black tracking-widest mb-1">
                    <Weight size={11} /> Weight
                  </div>
                  <p className="text-white font-semibold">{user.weight ? `${user.weight} kg` : <span className="text-zinc-700 italic font-normal">Not set</span>}</p>
                </div>

                <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-xl p-3">
                  <div className="flex items-center gap-1.5 text-[#F1C40F] text-[10px] uppercase font-black tracking-widest mb-1">
                    <Target size={11} /> Goal Weight
                  </div>
                  <p className="text-white font-semibold">{user.targetWeightKg ? `${user.targetWeightKg} kg` : <span className="text-zinc-700 italic font-normal">Not set</span>}</p>
                </div>

                <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-xl p-3">
                  <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] uppercase font-black tracking-widest mb-1">
                    <BarChart2 size={11} /> BMI
                  </div>
                  {bmi && bmiInfo ? (
                    <div>
                      <p className="text-white font-semibold">{bmi}</p>
                      <p className={`text-[9px] font-black uppercase tracking-wider mt-0.5 ${bmiInfo.color}`}>{bmiInfo.label}</p>
                    </div>
                  ) : <p className="text-white font-semibold"><span className="text-zinc-700 italic font-normal">N/A</span></p>}
                </div>

                <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-xl p-3">
                  <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] uppercase font-black tracking-widest mb-1">
                    <Ruler size={11} /> Height
                  </div>
                  {(() => {
                    const cm = (user as any).heightCm ?? (user.height ? parseFloat(user.height) : null);
                    return cm
                      ? <p className="text-white font-semibold">{cm} cm</p>
                      : <p className="text-white font-semibold"><span className="text-zinc-700 italic font-normal">Not set</span></p>;
                  })()}
                </div>

                <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-xl p-3">
                  <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] uppercase font-black tracking-widest mb-1">
                    <Activity size={11} /> Gender
                  </div>
                  <p className="text-white font-semibold capitalize">{user.gender || <span className="text-zinc-700 italic font-normal">Not set</span>}</p>
                </div>

                <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-xl p-3">
                  <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] uppercase font-black tracking-widest mb-1">
                    <Calendar size={11} /> Born
                  </div>
                  <p className="text-white font-semibold">
                    {user.dob ? new Date(user.dob).toLocaleDateString() : <span className="text-zinc-700 italic font-normal">Not set</span>}
                  </p>
                </div>

                <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-xl p-3 col-span-2 sm:col-span-1">
                  <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] uppercase font-black tracking-widest mb-2">
                    <Scale size={11} /> Units
                  </div>
                  <div className="flex bg-zinc-950 border border-zinc-800 rounded-lg overflow-hidden">
                    {(['METRIC', 'IMPERIAL'] as const).map(u => (
                      <button
                        key={u}
                        onClick={() => { setUnitPrefLocal(u); updatePref.mutate({ unitPreference: u }); }}
                        className={`flex-1 py-1.5 text-[9px] font-black uppercase tracking-widest transition-all ${unitPref === u ? 'bg-[#F1C40F] text-black' : 'text-zinc-500 hover:text-white'}`}
                      >{u === 'METRIC' ? 'kg' : 'lbs'}</button>
                    ))}
                  </div>
                </div>

                <div className="bg-zinc-900/40 border border-zinc-800/50 rounded-xl p-3 col-span-2 sm:col-span-2">
                  <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] uppercase font-black tracking-widest mb-2">
                    <Globe size={11} /> Language
                  </div>
                  <div className="flex bg-zinc-950 border border-zinc-800 rounded-lg overflow-hidden">
                    {([['EN','🇬🇧'], ['KA','🇬🇪'], ['RU','🇷🇺']] as const).map(([code, flag]) => (
                      <button
                        key={code}
                        onClick={() => { setLangPrefLocal(code); updatePref.mutate({ languagePreference: code }); }}
                        className={`flex-1 py-1.5 text-[9px] font-black uppercase tracking-widest transition-all flex items-center justify-center gap-1 ${langPref === code ? 'bg-[#F1C40F] text-black' : 'text-zinc-500 hover:text-white'}`}
                      ><span>{flag}</span>{code}</button>
                    ))}
                  </div>
                </div>
              </div>

              {user.medicalConditions ? (
                <div className="mt-4 p-4 bg-red-500/5 border border-red-500/10 rounded-xl">
                  <div className="flex items-center gap-2 mb-2">
                    <div className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
                    <p className="text-[10px] font-black uppercase tracking-widest text-red-400">Medical Conditions</p>
                   </div>
                  <p className="text-sm text-zinc-400 leading-relaxed font-medium">{user.medicalConditions}</p>
                </div>
              ) : user.noMedicalConditions ? (
                <div className="mt-4 p-4 bg-green-500/5 border border-green-500/10 rounded-xl">
                  <div className="flex items-center gap-2 mb-2">
                    <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                    <p className="text-[10px] font-black uppercase tracking-widest text-green-400">Medical Conditions</p>
                   </div>
                  <p className="text-sm text-zinc-400 leading-relaxed font-medium">No medical conditions or health problems reported.</p>
                </div>
              ) : (
                <div className="mt-4 p-4 bg-zinc-900/20 border border-zinc-800/30 rounded-xl">
                   <p className="text-[10px] font-black uppercase tracking-widest text-zinc-600 mb-1">Medical Conditions</p>
                   <p className="text-sm text-zinc-700 italic">None reported</p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Plans section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Workout Plans */}
        <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
          <div className="px-5 py-4 border-b border-zinc-800 flex items-center justify-between">
            <h2 className="font-semibold text-white flex items-center gap-2 text-sm">
              <Dumbbell size={15} className="text-[#F1C40F]" />
              Workout Plans
            </h2>
            <Link
              href={`/dashboard/trainer/members/${memberId}/workout`}
              className="text-xs font-bold text-[#F1C40F] hover:underline uppercase tracking-wider"
            >
              + New Plan
            </Link>
          </div>
          <div className="p-4 space-y-2 min-h-[80px]">
            {wpLoading ? (
              <p className="text-zinc-500 text-sm text-center py-4">Loading...</p>
            ) : !workoutPlans?.length ? (
              <p className="text-zinc-600 text-sm text-center py-4">No workout plans yet</p>
            ) : (
              workoutPlans.map((p) => (
                <PlanCard key={p.id} plan={p} memberId={memberId} type="workout" />
              ))
            )}
          </div>
        </div>

        {/* Diet Plans */}
        <div className="bg-[#121721] border border-zinc-800 rounded-xl overflow-hidden">
          <div className="px-5 py-4 border-b border-zinc-800 flex items-center justify-between">
            <h2 className="font-semibold text-white flex items-center gap-2 text-sm">
              <ClipboardList size={15} className="text-[#F1C40F]" />
              Diet Plans
            </h2>
            <Link
              href={`/dashboard/trainer/members/${memberId}/diet`}
              className="text-xs font-bold text-[#F1C40F] hover:underline uppercase tracking-wider"
            >
              + New Plan
            </Link>
          </div>
          <div className="p-4 space-y-2 min-h-[80px]">
            {dpLoading ? (
              <p className="text-zinc-500 text-sm text-center py-4">Loading...</p>
            ) : !dietPlans?.length ? (
              <p className="text-zinc-600 text-sm text-center py-4">No diet plans yet</p>
            ) : (
              dietPlans.map((p) => (
                <PlanCard key={p.id} plan={p} memberId={memberId} type="diet" />
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
