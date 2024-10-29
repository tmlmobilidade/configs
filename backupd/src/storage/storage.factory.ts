import { IStorageService } from '@/storage/storage.interface';

import { AwsStorageService, AwsStorageServiceConfiguration } from './aws-storage.service';

export interface StorageConfiguration {
	aws_config: AwsStorageServiceConfiguration

	// The type of storage service to use.
	type: 'aws' | 'oci'
}

export class StorageFactory {
	/**
     * Creates and returns an instance of a storage service based on the provided configuration.
     *
     * @param config - The storage configuration object.
     * @returns An instance of a class that implements IStorageService.
     */
	public static create(config: StorageConfiguration): IStorageService {
		switch (config.type) {
			case 'aws':
				return new AwsStorageService(config.aws_config);
		}
	}
}
