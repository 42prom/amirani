"use client";

import { useState, useEffect } from "react";
import { Upload as UploadIcon, RefreshCw as RefreshIcon, X as CloseIcon } from "lucide-react";
import NextImage from "next/image";
import { uploadApi, type UploadCategory } from "@/lib/api";

interface PhotoUploadZoneProps {
  label?: string;
  value?: string;
  onChange: (url: string) => void;
  folder: UploadCategory;
  token: string;
  className?: string;
  aspectRatio?: "square" | "video" | "auto";
}

export function PhotoUploadZone({
  label,
  value,
  onChange,
  folder,
  token,
  className = "",
  aspectRatio = "square",
}: PhotoUploadZoneProps) {
  const [uploading, setUploading] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(
    value ? uploadApi.getFullUrl(value) : null
  );

  // Sync preview when value changes externally
  useEffect(() => {
    if (value) {
      setPreviewUrl(uploadApi.getFullUrl(value));
    } else {
      setPreviewUrl(null);
    }
  }, [value]);

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);

    const file = e.dataTransfer.files?.[0];
    if (file && file.type.startsWith("image/")) {
      handleFileSelect(file);
    }
  };

  const handleFileSelect = async (file: File) => {
    setError(null);
    setUploading(true);

    try {
      // Create local preview immediately
      const previewReader = new FileReader();
      previewReader.onload = (e) => setPreviewUrl(e.target?.result as string);
      previewReader.readAsDataURL(file);

      // Resize image client-side before upload
      const optimizedFile = await resizeImage(file, 1200, 1200);
      const result = await uploadApi.uploadFile(optimizedFile, folder, token);
      onChange(result.url);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed");
      setPreviewUrl(value ? uploadApi.getFullUrl(value) : null);
    } finally {
      setUploading(false);
    }
  };

  const resizeImage = (file: File, maxWidth: number, maxHeight: number): Promise<File> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = (event) => {
        const img = new Image();
        img.src = event.target?.result as string;
        img.onload = () => {
          const canvas = document.createElement("canvas");
          let width = img.width;
          let height = img.height;

          if (width > height) {
            if (width > maxWidth) {
              height *= maxWidth / width;
              width = maxWidth;
            }
          } else {
            if (height > maxHeight) {
              width *= maxHeight / height;
              height = maxHeight;
            }
          }

          canvas.width = width;
          canvas.height = height;
          const ctx = canvas.getContext("2d");
          ctx?.drawImage(img, 0, 0, width, height);

          canvas.toBlob(
            (blob) => {
              if (blob) {
                const resizedFile = new File([blob], file.name, {
                  type: "image/jpeg",
                  lastModified: Date.now(),
                });
                resolve(resizedFile);
              } else {
                reject(new Error("Canvas to Blob failed"));
              }
            },
            "image/jpeg",
            0.85 // Quality
          );
        };
        img.onerror = () => reject(new Error("Failed to load image for resizing"));
      };
      reader.onerror = () => reject(new Error("Failed to read file"));
    });
  };

  const aspectClass = 
    aspectRatio === "square" ? "aspect-square" : 
    aspectRatio === "video" ? "aspect-video" : 
    "h-40";

  return (
    <div className={className}>
      {label && <label className="block text-xs font-bold text-zinc-500 uppercase tracking-widest mb-2">{label}</label>}
      <div 
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        className={`group relative ${aspectClass} bg-white/[0.02] border-2 border-dashed rounded-2xl flex flex-col items-center justify-center transition-all overflow-hidden backdrop-blur-sm cursor-pointer ${
          error ? "border-red-500/50" : previewUrl ? "border-green-500/50" : 
          isDragging ? "border-[#F1C40F] bg-[#F1C40F]/10 scale-[0.98]" :
          "border-white/10 hover:bg-white/[0.05] hover:border-[#F1C40F]/50"
        }`}
      >
        <input
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          className="absolute inset-0 opacity-0 cursor-pointer z-10"
          disabled={uploading}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) handleFileSelect(file);
          }}
        />
        {uploading ? (
          <div className="flex flex-col items-center">
            <RefreshIcon size={24} className="text-[#F1C40F] animate-spin mb-2" />
            <p className="text-[10px] font-black tracking-tight text-[#F1C40F]">UPLOADING...</p>
          </div>
        ) : previewUrl ? (
          <div className="relative w-full h-full">
            <NextImage src={previewUrl} alt="Preview" fill className="object-cover" />
            
            {!uploading && (
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  onChange("");
                }}
                className="absolute top-3 right-3 p-1.5 bg-black/60 hover:bg-red-500 text-white rounded-lg transition-all z-20 backdrop-blur-sm border border-white/10"
              >
                <CloseIcon size={16} />
              </button>
            )}

            <div className="absolute inset-0 bg-black/60 flex flex-col items-center justify-center opacity-0 group-hover:opacity-100 transition-all">
              <UploadIcon size={24} className="text-white mb-2" />
              <p className="text-[10px] font-black tracking-tight text-white uppercase">Replace Photo</p>
            </div>
          </div>
        ) : (
          <div className="flex flex-col items-center text-zinc-500 transition-all group-hover:text-zinc-300 px-6 text-center">
            <div className="w-12 h-12 bg-zinc-900/50 rounded-2xl flex items-center justify-center mb-3 group-hover:scale-110 transition-transform border border-white/5">
              <UploadIcon size={24} className="text-[#F1C40F]" />
            </div>
            <p className="text-[11px] font-black tracking-tight uppercase">Upload Visual Data</p>
            <p className="text-[9px] text-zinc-600 mt-1 uppercase font-bold">JPEG, PNG, WebP (Max 5MB)</p>
          </div>
        )}
      </div>
      {error && <p className="text-red-400 text-[10px] font-bold mt-2 uppercase tracking-tight">{error}</p>}
    </div>
  );
}
