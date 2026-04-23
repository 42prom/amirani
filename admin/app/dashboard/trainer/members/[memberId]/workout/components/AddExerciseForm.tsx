"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Dumbbell, X, Flame, Check } from "lucide-react";
import { trainerApi } from "@/lib/api";
import { ExerciseSearch } from "./ExerciseSearch";

interface AddExerciseFormProps {
  routineId: string;
  token: string;
  memberId: string;
  onDone: () => void;
}

export function AddExerciseForm({
  routineId, token, memberId, onDone,
}: AddExerciseFormProps) {
  const qc = useQueryClient();
  const [pendingName, setPendingName] = useState("");
  const [sets, setSets] = useState("3");
  const [reps, setReps] = useState("10");
  const [weight, setWeight] = useState("");
  const [rest, setRest] = useState("90");
  const [rpe, setRpe] = useState("");
  const [note, setNote] = useState("");

  const addEx = useMutation({
    mutationFn: () =>
      trainerApi.addExercises(routineId, [{
        exerciseName: pendingName,
        targetSets: parseInt(sets) || 3,
        targetReps: parseInt(reps) || 10,
        targetWeight: weight ? parseFloat(weight) : undefined,
        restSeconds: rest ? parseInt(rest) : undefined,
        rpe: rpe ? parseInt(rpe) : undefined,
        progressionNote: note || undefined,
      }], token),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["trainer-workout-plans", memberId] });
      setPendingName("");
      setNote("");
    },
  });

  const rpeNum = rpe ? parseInt(rpe) : 0;

  return (
    <div className="space-y-3 pt-2">
      <ExerciseSearch token={token} onSelect={setPendingName} />
      {!pendingName && (
        <input
          placeholder="Or type custom name + Enter…"
          onKeyDown={(e) => {
            if (e.key === "Enter" && e.currentTarget.value.trim()) {
              setPendingName(e.currentTarget.value.trim());
              e.currentTarget.value = "";
            }
          }}
          className="w-full bg-zinc-900/50 border border-zinc-800 rounded-lg px-3 py-2 text-sm text-white placeholder-zinc-600 outline-none focus:border-[#F1C40F]/50"
        />
      )}
      {pendingName && (
        <div className="bg-zinc-900 border border-zinc-700 rounded-xl p-4 space-y-3">
          <div className="flex items-center gap-2">
            <Dumbbell size={13} className="text-[#F1C40F]" />
            <p className="text-sm font-bold text-white">{pendingName}</p>
            <button onClick={() => setPendingName("")} className="ml-auto text-zinc-600 hover:text-zinc-400">
              <X size={12} />
            </button>
          </div>
          <div className="grid grid-cols-5 gap-2">
            {([
              ["Sets", sets, setSets],
              ["Reps", reps, setReps],
              ["kg", weight, setWeight],
              ["Rest s", rest, setRest],
              ["RPE", rpe, setRpe],
            ] as [string, string, (v: string) => void][]).map(([label, val, setter]) => (
              <div key={label}>
                <p className="amirani-label !mb-3">{label}</p>
                <input
                  type="number" min="0"
                  max={label === "RPE" ? "10" : undefined}
                  value={val}
                  onChange={(e) => setter(e.target.value)}
                  className="amirani-input"
                />
              </div>
            ))}
          </div>
          <div>
            <p className="amirani-label !mb-3">Coaching Note (optional)</p>
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={300}
              placeholder="e.g. Increase weight by 2.5kg next week…"
              className="amirani-input !h-10 text-xs"
            />
          </div>
          {rpeNum >= 8 && (
            <div className="flex items-center gap-1.5 px-3 py-2 bg-orange-500/10 border border-orange-500/20 rounded-lg">
              <Flame size={12} className="text-orange-400" />
              <span className="text-xs text-orange-400 font-semibold">
                High intensity — marked as <strong>challenge</strong> for the member
              </span>
            </div>
          )}
          <div className="flex gap-2">
            <button
              onClick={() => {
                addEx.mutate();
              }}
              disabled={addEx.isPending}
              className="flex items-center gap-1.5 px-4 h-[44px] bg-[#F1C40F] text-black text-xs font-bold rounded-lg hover:bg-[#F4D03F] disabled:opacity-50 transition-colors"
            >
              <Check size={12} />
              {addEx.isPending ? "Adding…" : "Add Exercise"}
            </button>
            <button
              onClick={onDone}
              className="px-4 h-[44px] bg-zinc-800 text-zinc-400 text-xs font-bold rounded-lg hover:bg-zinc-700 transition-colors"
            >
              Done
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
