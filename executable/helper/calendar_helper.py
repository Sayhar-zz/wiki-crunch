# /usr/bin/env python
# Based off the command-line-skeleton application for Calendar API from google


import argparse
import httplib2
import os
import sys
import pdb
from datetime import datetime
from datetime import timedelta

from apiclient import discovery
from oauth2client import file
from oauth2client import client
from oauth2client import tools

# Parser for command-line arguments.
parser = argparse.ArgumentParser(
    description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter,
    parents=[tools.argparser])


# CLIENT_SECRETS is name of a file containing the OAuth 2.0 information for this
# application, including client_id and client_secret. You can see the Client ID
# and Client secret on the APIs page in the Cloud Console:
# <https://cloud.google.com/console#/project/927701692446/apiui>
CLIENT_SECRETS = os.path.join(os.path.dirname(__file__), 'client_secrets.json')

# Set up a Flow object to be used for authentication.
# Add one or more of the following scopes. PLEASE ONLY ADD THE SCOPES YOU
# NEED. For more information on using scopes please see
# <https://developers.google.com/+/best-practices>.
FLOW = client.flow_from_clientsecrets(CLIENT_SECRETS,
  scope=[
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
    message=tools.message_if_missing(CLIENT_SECRETS))

service = ""
#GLOBAL ^
REPORTURL = "https://reports.frdev.wikimedia.org/reports/allreports/"

def eventbuilder(test):
  noEnd = False
  startstring = ""
  endstring = ""
  testid = test[0]['ID']
  description = []


  start = test[0]['Start time']
  if start is None:
    print "ERROR! No start time. Abort Abort."
    raise SystemExit(0)

  start = datetime.strptime(start, "%Y%m%d%H%M%S")
  startstring = start.strftime("%Y-%m-%dT%H:00:00Z")

  end = test[0]['End time']

  if end is not None:
    end = datetime.strptime(end, "%Y%m%d%H%M%S")
    endstring = end.strftime("%Y-%m-%dT%H:00:00Z")  
  else:
    noEnd = True
    end = start + timedelta(hours=1)
    endstring = end.strftime("%Y-%m-%dT%H:00:00Z")

  banners = []
  shots =   []
  shots2 =  []
  info =    []

  for line in test:
    banners.append(line['Banner'])
    shots.append(line['Screenshot'])
    shots2.append(line['Extra Screenshot'])
    info.append(line['Extra info'])
  description.append("\nvs.\n".join(banners))
  
  while None in info: info.remove(None)
  while None in shots: shots.remove(None)
  
  description.append("\n".join(info))

  description.append("")

  
  bannershots = zip(banners, shots)
  for bs in bannershots:
    description.append(" : ".join(bs))

  url = REPORTURL + testid + ".html"
  description.append(url)



  if noEnd:
    description.append("WARNING: End time is inaccurate")
  #pdb.set_trace()

  description = "\n\n".join(description)



  event = {
  'summary': testid,
  'start': {
    'dateTime': startstring
  },
  'end': {
    'dateTime': endstring
  },
  'description': description,
  #'location':url,
  'extendedProperties':{
    'shared':{
      'testid': testid
    }
  }
  }  



  return event

def eventbuilder_blank():
  #take in a test in the form of dictReader rows from the spreadsheet.
  #testid, start, end, banners, screenshots
  
  #What do we need for a real eventbuilder?
  # 1. Testid
  # 2. Start and end time
  # 3. Banners
  # 4. Screenshots
  # 5. Link to report
  # 
  # 
  # 
  # 
  event = {
  'summary': 'Appointment',
  'location': 'Somewhere',
  'start': {
    'dateTime': '2014-01-01T01:00:00Z'
  },
  'end': {
    'dateTime': '2014-01-01T20:20:20Z'  
  },
  'description':'this is a test description',
  'extendedProperties':{
    'shared':{
      'testid':'B13_1120_clrhl'
    }
  }
  }
  return event




def get_cal_id():
  cals = service.calendarList().list().execute()['items']
  id2 = cals[1]['id'] 

  #1 = testing.
  #2 = REAL
  #0 = default/ignore
  return id2



def insert_or_update(event, calendar):
  #given an event, either update an already-existing event or insert it
  #How do you find the already-existing event? It should start on the same day as this event, and also
  # have the same testid (saved in extendedProperties-shared-testid)
  doinsert = True
  updateThis = ''
  seqNum = 0
  target_testid = event['extendedProperties']['shared']['testid']
  #nend = event['end']['dateTime']
  
  try:
    list_today = service.events().list(calendarId=calendar, orderBy="startTime", timeMin=event['start']['dateTime'], singleEvents=True).execute()['items']
    if len(list_today) != 0:
      for item in list_today:
        #assumes you'll only find 1 thing to update
        if item['extendedProperties']['shared']['testid'] == target_testid:
          #when we find thething to update, we save it's ID
          updateThis = item['id']
          seqNum = int(item['sequence']) + 1
          doinsert = False
          # when updating you gotta increment the sequence number
  except:
    doinsert = True

  event['sequence'] = str(seqNum)


  if doinsert:
    calendarevent = service.events().insert(body=event, calendarId=calendar).execute()
  else:
    #update instead
    calendarevent = service.events().update(body=event, calendarId=calendar, eventId=updateThis).execute()

  print calendarevent
  #^ Temporary?






def sample():
  #writes or updates sample event on Jan 1 2014
  id2 = get_cal_id()
  event = eventbuilder_blank()
  insert_or_update(event, id2)
  #ch.service.events().list(calendarId=id, orderBy="startTime", timeMin=event['start']['dateTime'], singleEvents=True).execute()['items']









def easyinsert(test):
  id2 = get_cal_id()
  event = eventbuilder(test)
  insert_or_update(event, id2)




def init():
  # Parse the command-line flags.
  argv = ['', '--noauth_local_webserver']
  flags = parser.parse_args(argv[1:])

  # If the credentials don't exist or are invalid run through the native client
  # flow. The Storage object will ensure that if successful the good
  # credentials will get written back to the file.
  storage = file.Storage('credentials.dat')
  credentials = storage.get()
  if credentials is None or credentials.invalid:
    credentials = tools.run_flow(FLOW, storage, flags)

  # Create an httplib2.Http object to handle our HTTP requests and authorize it
  # with our good Credentials.
  http = httplib2.Http()
  http = credentials.authorize(http)

  # Construct the service object for the interacting with the Calendar API.
  global service
  service = discovery.build('calendar', 'v3', http=http)

  try:
    #print "Success!"
    pass
  except client.AccessTokenRefreshError:
    print ("The credentials have been revoked or expired, please re-run"
      "the application to re-authorize")
    return


#Init gives us a global object service that the other methods will use
init()






# For more information on the Calendar API you can visit:
#
#   https://developers.google.com/google-apps/calendar/firstapp
#
# For more information on the Calendar API Python library surface you
# can visit:
#
#   https://developers.google.com/resources/api-libraries/documentation/calendar/v3/python/latest/
#
# For information on the Python Client Library visit:
#
#   https://developers.google.com/api-client-library/python/start/get_started
