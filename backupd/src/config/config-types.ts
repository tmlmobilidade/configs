import { BackupConfig } from '@/backup/backup.service';
import { MongoDbConfig } from '@/database/mongo.service';
import { PostgresConfig } from '@/database/postgres.service';
import { EmailConfig } from '@/mailer/mailer.service';
import { AwsStorageServiceConfiguration } from '@/storage/aws-storage.service';

export interface StorageConfig {
	aws_config?: AwsStorageServiceConfiguration
	oci_config?: {
		fingerprint: string
		private_key_path: string
		tenancy: string
		user: string
	}
	type: 'aws' | 'oci'
}

export interface MongoDBOptions {
	connectTimeoutMS: number
	directConnection: boolean
	maxPoolSize: number
	minPoolSize: number
	readPreference: string
	serverSelectionTimeoutMS: number
}

export interface DatabaseConfig {
	mongodb_config?: MongoDbConfig
	postgres_config?: PostgresConfig
	type: 'mongodb' | 'postgres'
}

export interface AppConfig {
	backup: BackupConfig
	database: DatabaseConfig
	email?: EmailConfig
	storage: StorageConfig
}
