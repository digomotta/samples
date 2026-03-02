import type React from "react";
import { useState } from "react";

interface AgentControlsProps {
  isRunning: boolean;
  isPaused: boolean;
  onStart: (goal: string) => void;
  onPause: () => void;
  onResume: () => void;
  onStop: () => void;
  onIntervene: (message: string) => void;
}

function AgentControls({
  isRunning,
  isPaused,
  onStart,
  onPause,
  onResume,
  onStop,
  onIntervene,
}: AgentControlsProps) {
  const [goal, setGoal] = useState("buy some cookies");
  const [intervention, setIntervention] = useState("");

  const handleStartSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (goal.trim()) onStart(goal.trim());
  };

  const handleInterveneSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (intervention.trim()) {
      onIntervene(intervention.trim());
      setIntervention("");
    }
  };

  if (!isRunning) {
    return (
      <div className="bg-white p-3 border-t border-gray-200 shadow-t-sm flex-shrink-0">
        <form
          onSubmit={handleStartSubmit}
          className="flex items-center space-x-3 max-w-4xl mx-auto"
        >
          <div className="flex-grow flex items-center space-x-2">
            <label htmlFor="goal-input" className="text-sm text-gray-500 whitespace-nowrap">
              Goal:
            </label>
            <input
              id="goal-input"
              type="text"
              value={goal}
              onChange={(e) => setGoal(e.target.value)}
              placeholder="What should the buyer agent shop for?"
              className="flex-grow p-3 border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-indigo-400 transition"
              autoComplete="off"
            />
          </div>
          <button
            type="submit"
            disabled={!goal.trim()}
            className="bg-indigo-500 text-white px-5 py-3 rounded-full disabled:bg-indigo-300 disabled:cursor-not-allowed hover:bg-indigo-600 transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:ring-offset-2 text-sm font-medium"
          >
            Start Agent
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="bg-white p-3 border-t border-gray-200 shadow-t-sm flex-shrink-0">
      <div className="flex items-center space-x-3 max-w-4xl mx-auto">
        <form
          onSubmit={handleInterveneSubmit}
          className="flex-grow flex items-center space-x-2"
        >
          <input
            type="text"
            value={intervention}
            onChange={(e) => setIntervention(e.target.value)}
            placeholder="Override: type a message to send instead..."
            className="flex-grow p-3 border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-indigo-400 transition"
            autoComplete="off"
          />
          <button
            type="submit"
            disabled={!intervention.trim()}
            className="bg-indigo-500 text-white px-4 py-3 rounded-full disabled:bg-indigo-300 disabled:cursor-not-allowed hover:bg-indigo-600 transition-colors text-sm font-medium"
          >
            Send
          </button>
        </form>
        <div className="flex items-center space-x-2">
          {isPaused ? (
            <button
              type="button"
              onClick={onResume}
              className="bg-green-500 text-white px-4 py-3 rounded-full hover:bg-green-600 transition-colors text-sm font-medium"
            >
              Resume
            </button>
          ) : (
            <button
              type="button"
              onClick={onPause}
              className="bg-yellow-500 text-white px-4 py-3 rounded-full hover:bg-yellow-600 transition-colors text-sm font-medium"
            >
              Pause
            </button>
          )}
          <button
            type="button"
            onClick={onStop}
            className="bg-red-500 text-white px-4 py-3 rounded-full hover:bg-red-600 transition-colors text-sm font-medium"
          >
            Stop
          </button>
        </div>
      </div>
    </div>
  );
}

export default AgentControls;
