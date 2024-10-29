import { DeleteObjectCommand, DeleteObjectsCommand, GetObjectCommand, ListObjectsV2Command, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { Readable } from 'stream';

import { IStorageService } from './storage.interface';

export interface AwsStorageServiceConfiguration {
	aws_access_key_id: string
	aws_secret_access_key: string
	bucket_name: string
	region?: string
}

export class AwsStorageService implements IStorageService {
	private readonly bucketName: string;
	private readonly s3Client: S3Client;

	constructor(config: AwsStorageServiceConfiguration) {
		this.s3Client = new S3Client({
			credentials: {
				accessKeyId: config.aws_access_key_id,
				secretAccessKey: config.aws_secret_access_key,
			},
			region: config.region || 'eu-south-2', // Default region, Spain
		});
		this.bucketName = config.bucket_name;
	}

	/**
	 * Deletes a file from S3.
	 * @param key - The file path and name in S3.
	 */
	async deleteFile(key: string): Promise<void> {
		try {
			const command = new DeleteObjectCommand({
				Bucket: this.bucketName,
				Key: key,
			});
			await this.s3Client.send(command);
			console.log(`File deleted successfully from ${this.bucketName}/${key}`);
		}
		catch (error) {
			console.error('Error deleting file:', error);
			throw error;
		}
	}

	/**
	 * Deletes multiple files from S3.
	 * @param keys - The file paths and names in S3.
	 */
	async deleteFiles(keys: string[]): Promise<void> {
		try {
			const command = new DeleteObjectsCommand({
				Bucket: this.bucketName,
				Delete: { Objects: keys.map(key => ({ Key: key })) },
			});
			await this.s3Client.send(command);
		}
		catch (error) {
			console.error('Error deleting files:', error);
			throw error;
		}
	}

	/**
	 * Downloads a file from S3.
	 * @param key - The file path and name in S3.
	 * @returns The file as a readable stream.
	 */
	async downloadFile(key: string): Promise<Readable> {
		try {
			const command = new GetObjectCommand({
				Bucket: this.bucketName,
				Key: key,
			});
			const response = await this.s3Client.send(command);
			if (!response.Body) {
				throw new Error(`Failed to download file: ${key} does not exist.`);
			}
			return response.Body as Readable;
		}
		catch (error) {
			console.error('Error downloading file:', error);
			throw error;
		}
	}

	/**
	 * Lists files in an S3 bucket.
	 * @param prefix - Filter by prefix (optional).
	 * @returns Array of file keys in the bucket.
	 */
	async listFiles(prefix?: string): Promise<string[]> {
		try {
			const command = new ListObjectsV2Command({
				Bucket: this.bucketName,
				Prefix: prefix,
			});
			const response = await this.s3Client.send(command);
			return response.Contents ? response.Contents.map(item => item.Key || '') : [];
		}
		catch (error) {
			console.error('Error listing files:', error);
			throw error;
		}
	}

	/**
	 * Uploads a file to S3.
	 * @param key - The file path and name in S3.
	 * @param body - The content to upload, either as a string, buffer, or readable stream.
	 */
	async uploadFile(key: string, body: Buffer | Readable | string): Promise<void> {
		try {
			const command = new PutObjectCommand({
				Body: body,
				Bucket: this.bucketName,
				Key: key,
			});
			await this.s3Client.send(command);
			console.log(`File uploaded successfully to ${this.bucketName}/${key}`);
		}
		catch (error) {
			console.error('Error uploading file:', error);
			throw error;
		}
	}
}
