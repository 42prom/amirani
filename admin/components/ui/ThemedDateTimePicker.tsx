"use client";

import { ThemedDatePicker } from "./ThemedDatePicker";
import { ThemedTimePicker } from "./ThemedTimePicker";

interface ThemedDateTimePickerProps {
  label?: string;
  value?: string; // YYYY-MM-DDTHH:mm
  onChange: (value: string) => void;
  required?: boolean;
  className?: string;
}

export function ThemedDateTimePicker({
  label,
  value,
  onChange,
  required,
  className = "",
}: ThemedDateTimePickerProps) {
  // Split value into date and time
  const [datePart, timePart] = value ? value.split("T") : ["", ""];

  const handleDateChange = (newDate: string) => {
    const time = timePart || "12:00";
    if (!newDate) {
      onChange("");
    } else {
      onChange(`${newDate}T${time}`);
    }
  };

  const handleTimeChange = (newTime: string) => {
    const date = datePart || new Date().toISOString().split("T")[0];
    onChange(`${date}T${newTime}`);
  };

  return (
    <div className={className}>
      {label && (
        <label className="amirani-label !mb-3">
          {label} {required && <span className="text-[#F1C40F]">*</span>}
        </label>
      )}
      
      <div className="flex flex-col sm:flex-row gap-3">
        <ThemedDatePicker
          value={datePart}
          onChange={handleDateChange}
          className="flex-1"
        />
        <ThemedTimePicker
          value={timePart}
          onChange={handleTimeChange}
          className="sm:w-48"
        />
      </div>
    </div>
  );
}
