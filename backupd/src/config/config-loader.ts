// configLoader.ts
import * as fs from 'fs';
import * as yaml from 'yaml';

import { AppConfig } from './config-types';

function validateConfig(config: AppConfig) {
	//

	//
	// Validate storage configuration
	if (!config.storage) {
		throw new Error('Missing required field \'storage\' configuration.');
	}

	if (config.storage.type !== 'aws' && config.storage.type !== 'oci') {
		throw new Error('Invalid storage type. Supported types are \'aws\' and \'oci\'.');
	}

	if (config.storage.type === 'aws') {
		if (!config.storage.aws_config) {
			throw new Error('Storage type is \'aws\' but \'aws_config\' is missing.');
		}
		const { aws_access_key_id, aws_secret_access_key, bucket_name, region } = config.storage.aws_config;
		if (!aws_access_key_id || !aws_secret_access_key || !bucket_name || !region) {
			throw new Error('Missing required fields in \'aws_config\'. Ensure \'aws_access_key_id\', \'aws_secret_access_key\', \'bucket_name\', and \'region\' are set.');
		}
	}
	else if (config.storage.type === 'oci') {
		if (!config.storage.oci_config) {
			throw new Error('Storage type is \'oci\' but \'oci_config\' is missing.');
		}
		const { fingerprint, private_key_path, tenancy, user } = config.storage.oci_config;
		if (!tenancy || !user || !fingerprint || !private_key_path) {
			throw new Error('Missing required fields in \'oci_config\'. Ensure \'tenancy\', \'user\', \'fingerprint\', and \'private_key_path\' are set.');
		}
	}

	//
	// Validate database configuration
	if (!config.database) {
		throw new Error('Missing required field \'database\' configuration.');
	}

	if (config.database.type !== 'mongodb' && config.database.type !== 'postgres') {
		throw new Error('Invalid database type. Supported types are \'mongodb\' and \'postgres\'.');
	}

	if (config.database.type === 'mongodb') {
		if (!config.database.mongodb_config) {
			throw new Error('Database type is \'mongodb\' but \'mongodb_config\' is missing.');
		}
		if (!config.database.mongodb_config.uri) {
			throw new Error('Missing required field \'uri\' in \'mongodb_config\'.');
		}
	}
	else if (config.database.type === 'postgres') {
		if (!config.database.postgres_config) {
			throw new Error('Database type is \'postgres\' but \'postgres_config\' is missing.');
		}
		if (!config.database.postgres_config.uri) {
			throw new Error('Missing required field \'uri\' in \'postgres_config\'.');
		}
	}

	//
	// Validate Backup configuration
	if (!config.backup) {
		throw new Error('Missing required field \'backup\' configuration.');
	}

	if (!config.backup.interval) {
		throw new Error('Missing required field \'interval\' in \'backup\' configuration.');
	}
	else if (config.backup.interval <= 0 || typeof config.backup.interval !== 'number') {
		throw new Error('\'interval\' must be a number greater than 0 in \'backup\' configuration.');
	}

	if (!config.backup.destination) {
		throw new Error('Missing required field \'destination\' in \'backup\' configuration.');
	}

	if (!config.backup.max_local_backups) {
		console.warn('\'max_local_backups\' is not set in \'backup\' configuration. No backups will be deleted.');
	}
	else if (config.backup.max_local_backups <= 0 || typeof config.backup.max_local_backups !== 'number') {
		throw new Error('\'max_local_backups\' must be a number greater than 0 in \'backup\' configuration.');
	}

	if (!config.backup.max_remote_backups) {
		console.warn('\'max_remote_backups\' is not set in \'backup\' configuration. No backups will be stored in the device storage.');
	}
	else if (config.backup.max_remote_backups <= 0 || typeof config.backup.max_remote_backups !== 'number') {
		throw new Error('\'max_remote_backups\' must be a number greater than 0 in \'backup\' configuration.');
	}

	//
	// Validate Email configuration
	if (!config.email) {
		console.warn('\'email\' configuration is not set. No email will be sent.');
	}
	else {
		const { mail_options, send_failure, send_success, smtp } = config.email;
		if (typeof send_success !== 'boolean') {
			throw new Error('\'email.send_success\' should be a boolean.');
		}
		if (typeof send_failure !== 'boolean') {
			throw new Error('\'email.send_failure\' should be a boolean.');
		}
		if (!mail_options) {
			throw new Error('Missing \'mail_options\' in email configuration.');
		}
		if (!smtp) {
			throw new Error('Missing \'smtp\' configuration in email.');
		}
		else {
			const { host, port } = smtp;
			if (!host) {
				throw new Error('Missing \'host\' in \'smtp\' configuration.');
			}
			if (typeof port !== 'number' || port <= 0) {
				throw new Error('\'smtp.port\' should be a positive number.');
			}
			if (!smtp.auth.user) {
				throw new Error('Missing \'user\' in \'smtp.auth\' configuration.');
			}
			if (!smtp.auth.pass) {
				throw new Error('Missing \'password\' in \'smtp.auth\' configuration.');
			}
		}
	}
}

export function loadConfig(path: string): AppConfig {
	try {
		const fileContents = fs.readFileSync(path, 'utf8');
		const config = yaml.parse(fileContents) as AppConfig;

		// Validate the parsed configuration
		validateConfig(config);

		return config;
	}
	catch (error) {
		if (error instanceof SyntaxError) {
			throw new Error(`YAML Syntax Error in config file: ${error.message}`);
		}
		else if (error.code === 'ENOENT') {
			throw new Error(`Configuration file not found at path: ${path}`);
		}
		else {
			throw new Error(`Failed to load configuration: ${error.message}`);
		}
	}
}
