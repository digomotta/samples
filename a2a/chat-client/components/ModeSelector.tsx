import { AppMode } from "../types";

interface ModeSelectorProps {
  mode: AppMode;
  onModeChange: (mode: AppMode) => void;
  disabled: boolean;
}

function ModeSelector({ mode, onModeChange, disabled }: ModeSelectorProps) {
  return (
    <div className="flex bg-gray-100 rounded-full p-0.5">
      <button
        type="button"
        onClick={() => onModeChange(AppMode.HUMAN_CHAT)}
        disabled={disabled}
        className={`px-3 py-1 text-xs font-medium rounded-full transition-colors ${
          mode === AppMode.HUMAN_CHAT
            ? "bg-white text-gray-800 shadow-sm"
            : "text-gray-500 hover:text-gray-700"
        } disabled:opacity-50 disabled:cursor-not-allowed`}
      >
        Chat
      </button>
      <button
        type="button"
        onClick={() => onModeChange(AppMode.BUYER_AGENT)}
        disabled={disabled}
        className={`px-3 py-1 text-xs font-medium rounded-full transition-colors ${
          mode === AppMode.BUYER_AGENT
            ? "bg-indigo-500 text-white shadow-sm"
            : "text-gray-500 hover:text-gray-700"
        } disabled:opacity-50 disabled:cursor-not-allowed`}
      >
        Agent-to-Agent
      </button>
    </div>
  );
}

export default ModeSelector;
