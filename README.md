# dhis2_owner_jobs

Routine for updating DHIS2 Tracker enrolling orgUnit to the enrollment's most recent "owner" orgUnit/facility. Useful for longitudinal analytics.

R 4.0 or above required

These packages are downloaded and loaded if not currently in use: "httr","assertthat","readr","jsonlite","stringr","purrr"

Repo includes blank auth.json file containing the credentials of the default server to use. The script relies on a username with SuperUser role to have an account in the server with access to update enrollments and read/create SQL views.

``` json
{
  "dhis": {
    "baseurl": "https://who-dev.dhis2.org/tracker_dev",
    "username": "robot",
    "password": "TOPSECRET"
  }
}
```

## Usage

1.  optional arguments:

    -startdate the start date to extract tracker data from

    -enddate the end date to extract data until

    By default updates enrollments from the **previous two days** unless dates are specified
