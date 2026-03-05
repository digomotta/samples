/*
 * Copyright 2026 UCP Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { AppMode } from "../types";
import ModeSelector from "./ModeSelector";

interface HeaderProps {
  logoUrl: string;
  title: string;
  mode: AppMode;
  onModeChange: (mode: AppMode) => void;
  isModeChangeDisabled: boolean;
}

function Header({ logoUrl, title, mode, onModeChange, isModeChangeDisabled }: HeaderProps) {
  return (
    <header className="bg-white shadow-sm p-4 border-b border-gray-200 flex-shrink-0">
      <div className="flex justify-between items-center">
        <h1 className="text-xl font-bold text-gray-800 flex items-center">
          <img
            src={logoUrl}
            alt="Logo"
            className="h-8 mr-3"
          />
          <span>{title}</span>
        </h1>
        <ModeSelector
          mode={mode}
          onModeChange={onModeChange}
          disabled={isModeChangeDisabled}
        />
      </div>
    </header>
  );
}

export default Header;
