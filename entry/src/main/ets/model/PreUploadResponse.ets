import { DeviceInfo } from "./DeviceInfo";
import { File } from "./FileInfo";

export interface PreUploadRequest {
  info: DeviceInfo;
  files: Record<string, File>;
}

export interface PreUploadResponse {
  sessionId: string,
  files: Record<string, string>
}