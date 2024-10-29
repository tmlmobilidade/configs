import { BackupService } from './backup/backup.service';
import { loadConfig } from './config/config-loader';
import { DatabaseConfiguration, DatabaseFactory } from './database/database.factory';
import { MailerService } from './mailer/mailer.service';
import { StorageConfiguration, StorageFactory } from './storage/storage.factory';

const config = loadConfig(process.env.CONFIG_PATH);

const databaseConfig: DatabaseConfiguration = {
	mongodb_config: config.database.mongodb_config,
	postgres_config: config.database.postgres_config,
	type: config.database.type,
};

const storageConfig: StorageConfiguration = {
	aws_config: config.storage.aws_config,
	// oci_config: config.storage.oci_config, // TODO: Add OCI Implementation
	type: config.storage.type,
};

// Create database and storage services
const database = DatabaseFactory.create(databaseConfig);
const storage = StorageFactory.create(storageConfig);
const backup = new BackupService(config.backup, database, storage);
const mailer = new MailerService(config.email);

async function main() {
	console.log('Running backup...');

	try {
		// Connect to the database
		await database.connect();

		// Perform backup
		await backup.backup();

		if (config.email?.send_success) {
			await mailer.sendSuccessMail();
		}
	}
	catch (error) {
		console.error('Error during backup:', error);

		if (config.email?.send_failure) {
			await mailer.sendFailureMail();
		}
	}
	finally {
		// Disconnect from the database
		await database.disconnect();
	}

	await new Promise(resolve => setTimeout(resolve, config.backup.interval * 1000));
	main();
}

main().catch((err) => {
	console.error(err);
});
