/**
 * CogLog v0.9.1 — TypeScript type definitions.
 */

export interface FactLayerSchema {
  user: string;
  thinking: string;
  assistant: string;
}

export interface InterpretationLayerSchema {
  current_focus: string;
  theory_of_mind: string;
  self_narrative: string;
  annotation: string;
}

export interface ConstraintsSchema {
  window_size: string;
  interpretation_empty: string;
}

export interface Schema {
  version: string;
  fact_layer: FactLayerSchema;
  interpretation_layer: InterpretationLayerSchema;
  constraints: ConstraintsSchema;
}

export interface Layers {
  user: string;
  thinking: string;
  assistant: string;
}

export interface Entry {
  _schema: Schema;
  turn_id: number;
  timestamp: string;
  layers: Layers;
  current_focus: string;
  theory_of_mind: string;
  self_narrative: string;
  annotation: string;
}

export interface WriteArgs {
  user: string;
  thinking: string;
  assistant: string;
  current_focus: string;
  theory_of_mind: string;
  self_narrative: string;
  annotation: string;
}

export interface ClearResult {
  cleared: boolean;
  reason?: string;
}

export declare class MetaLog {
  readonly dataDir: string;
  readonly currentFile: string;
  constructor();
  read(): Promise<Entry | null>;
  write(args: WriteArgs): Promise<Entry>;
  clear(): Promise<ClearResult>;
}
