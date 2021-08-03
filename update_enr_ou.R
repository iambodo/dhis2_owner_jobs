# update an enrollment org unit to ownership OU


## ISSUES
# Uses the OLD Tracker importer endpoints
# I only want to update the enrollment -- why download the whole TEI?
# Downloads and PUTs each enrollment independently with new ou 

## Include start and end dates as arguments in prompt

####Load required packages
packages<-c("httr","assertthat","readr","jsonlite","stringr","purrr")      
install_or_load_pack <- function(pack){
  create.pkg <- pack[!(pack %in% installed.packages()[, "Package"])]
  if (length(create.pkg))
    install.packages(create.pkg, dependencies = TRUE)
  sapply(pack, require, character.only = TRUE)
}

install_or_load_pack(packages)


# Extract login info from directory
if (!file.exists("auth.json")){
  stop("Please add auth.json to directory") 
} else {
  baseurl<-chuck(fromJSON("auth.json"), "dhis","baseurl")
  username<-chuck(fromJSON("auth.json"), "dhis","username")
  }


##test login
loginDHIS2<-function(baseurl,username,password){
  url<-paste0(baseurl,"api/me")
  r<-GET(url,authenticate(username,password))
  assert_that(r$status_code == 200L)}

if(loginDHIS2(baseurl,username,
              chuck(fromJSON("auth.json"), "dhis","password"))){
  print("successfully logged in")
}else{
  stop("could not log in! Please check url, username and password in auth.json")
}



### Start/end dates from arguments
is_date<- function(x, format) {
  formatted = try(as.Date(x, format), silent = TRUE)
  return(as.character(formatted) == x)
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args > 1) & is_date(args[1]==TRUE) & is_date(args[2]==TRUE)){
  start_date<-args[1]
  end_date<-args[2]
} else {
  warning("Start/end dates missing of invalid (yyyy-mm-dd)...\nReturning last two days by default")
  start_date<-Sys.Date()-2
  end_date<-Sys.Date()
}



### Extract ownership changes by SQL view

#Identify the SQL View UID and name 
view_uid <- "J2OMpRWK46j"
view_name<-"sqlView_ownership.json"

url<-paste0(baseurl,"api/sqlViews.json?filter=id:eq:",view_uid)
r<-httr::GET(url)
httr::stop_for_status(r, "Could not access SQL view. Check user permissions")

sql <- fromJSON(content(r, type="text", encoding = "UTF-8"))

if(is.null(pluck(sql, "sqlViews","id"))){
  
  warning("no SQL view with this uid exists. Creating new SQL view.")
  
  if(!all(file.exists(view_name)))
    stop("no JSON file for SQL view import in your directory")
  
  url<-paste0(baseurl,"api/27/metadata.json?importStrategy=CREATE")
  
  r<-POST(url, body=upload_file(view_name))
  
  url<-paste0(baseurl,"api/sqlViews.json?filter=id:eq:",view_uid)
  r<-httr::GET(url)

  httr::stop_for_status(r, "Could not post SQL view. Please check user permissions")
  
} else {
  warning(paste0("Ownership SQL view exists... Extracting data"))
}


## Now extract the data from SQL View into "movers" DF

sView<-paste0(baseurl,"api/sqlViews/rToBDbONXkA/data.csv",
              "?filter=po_date:ge:",start_date,
              "&filter=po_date:le:",end_date)
r<-GET(sView)
stop_for_status(r)


movers<-suppressMessages(read_csv(content(r)))

# add columns
movers$job_outcome<-as.character(NA)
movers$job_time<-Sys.time()

# function to update the enrollment orgunit

updateEnrOU<-function(baseurl, enr_id, new_ou){
  
  t_url<-paste0(baseurl,"api/enrollments")
  url<-paste0(t_url, "/",enr_id,".json")
  
  enr<-fromJSON(content(GET(url), type="text", encoding = "UTF-8") )

  pluck(enr,"orgUnit")<-new_ou #replace OU
  
  r<-httr::PUT(url,body=toJSON(enr, auto_unbox=TRUE),content_type_json())
  
  stop_for_status(r)
  
  return(pluck(httr::http_status(r),"message"))
  
}

if nrow(movers)>0{


# Start loop for updating enrollment OU
# Add status of operation to outcome column
for (i in 1:nrow(movers)){
  movers$job_outcome[i]<-updateEnrOU(baseurl, movers$curr_enr_uid[i],
                                          movers$po_orgunit_uid[i])
}

# Show results
print(paste0("Total enrollments: ", nrow(movers)))
print(table(movers$program_name, movers$job_outcome))


# Log to CSV
if(file.exists("updated_enrollments.csv")){
  log<-suppressMessages(read_csv("updated_enrollments.csv"))
  log<-rbind(log, movers)
  write_csv(log, "updated_enrollments.csv")
} else{
  write_csv(movers, "updated_enrollments.csv")
}

print("Details at updated_enrollments.csv")


} else {
  print("No enrollments found to update")
}

#### NEW TRACKER TEST ####
# this test with new tracker API created a tracker import job
# but did not update enrollment OU

# t_url<-paste0(baseurl,"api/tracker/")
# url<-paste0(t_url, "enrollments?enrollment=RhLh3xqQShQ")
# 
# enr<-fromJSON(content(GET(url), type="text", encoding = "UTF-8") )
# enr
# pluck(enr,"instances",  "orgUnit")<-"TSyzvBiovKh"
# 
# r<-httr::POST(url = t_url, body=toJSON(enr, auto_unbox=TRUE),content_type_json())
# 
# write_json(enr, "test_enr_imp.json")




