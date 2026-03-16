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