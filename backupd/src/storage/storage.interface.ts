import { Readable } from 'stream';

export interface IStorageService {
	// Delete a file from the storage.
	deleteFile(key: string): Promise<void>

	// Delete multiple files from the storage.
	deleteFiles(keys: string[]): Promise<void>

	// List files in the storage.
	listFiles(prefix?: string): Promise<string[]>

	// Upload a file to the storage.
	uploadFile(key: string, body: Buffer | Readable | string): Promise<void>
}
