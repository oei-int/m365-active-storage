# m365-active-storage

Rails ActiveStorage in M365 Sharepoint

## Install the gem

```ruby
gem install m365_active_storage
```
or add to the Gemfile:

```ruby
gem "m365_active_storage"
```

## Configure ActiveStorage

### Configure Active Storage and auth
#### Rails credentials
```yaml
sharepoint:
  ms_graph_url:
  ms_graph_version:
  auth_host:
  oauth_tenant:
  oauth_app_id:
  oauth_secret:
  sharepoint_site_id:
  sharepoint_drive_id:
  storage_key:
```
#### -- or --

#### ENV
```shell
MS_GRAPH_URL=
MS_GRAPH_VERSION=
AUTH_HOST=
OAUTH_TENANT=
OAUTH_APP_ID=
OAUTH_SECRET=
SHAREPOINT_SITE_ID=
SHAREPOINT_DRIVE_ID=
STORAGE_KEY=
```

### Set storage key
The storage key set when the file is stored using the blob key or the filename.
```ruby
storage_key: key | filename
```
#### Using the key store:
Stores the files with the blob key in the sharepoint drive, with no extension. If 
a file is uploaded more than once will be stored each time.

#### Using the filename store:
Stores the files using the filename instead of the key. In this case
a if a file is uploaded twice only the last will remain in the sharepoint drive.

With the filename storage, it's possible to manage folders to store the documents, allowing having
files with the same name into different folders.

In your app the path of the file can be set on the document attach:
```ruby
model.attachment.attach(
  io: file,
  filename: file.original_filename,
  metadata: { "sharepoint_folder" => "documents/#{Date.today.year}/#{Date.today.strftime('%m')}" }
)
```
This will create or use the nested folder structure, in this example:
```shell
documents/
  2026/
    03/
```



### Set active storage to sharepoint service
In the app config/environments/`<environment>`.rb

```ruby
  config.active_storage.service = :sharepoint
```

### Run the check generator
```
$ rails g m365_active_storage:check
```

## Move files from local to sharepoint with the migrate generator
```shell
g m365_active_storage:migrate
```

```shell
5 blobs to migrate
filename_1 done
filename_2 done
filename_3 done
filename_4 failed: ActiveStorage::FileNotFoundError
filename_5 done
...
```

> [!NOTE]
>
> The local files are still in the storage folder.
>
> You must delete them manually after validating the data has been correctly moved.
>

> [!NOTE]
>
> Don't forget to restart your server, if running
>