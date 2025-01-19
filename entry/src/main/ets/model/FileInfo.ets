import { DeviceInfo } from "./DeviceInfo";

export interface File {
  id: string;
  fileName: string;
  size: number;
  fileType: string;
}

// export interface IFileMetaData {
//   info: DeviceInfo;
//   files: Record<string, File>;
// }

export interface FileInfoSaved {
  fileName: string,
  token: string,
  fileSize: number
}

export interface FileInfoSent {
  fileUri: string,
  fileId: string,
  fileToken: string
}