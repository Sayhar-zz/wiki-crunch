# -*- coding: utf-8 -*-
#
# Copyright (C) 2013 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Command-line skeleton application for Calendar API.
Usage:
  $ python sample.py

You can also get help on all the command-line flags the program understands
by running:

  $ python sample.py --help

"""

event2 = {
  'summary': 'Appointment',
  'location': 'Somewhere',
  'start': {
    'dateTime': '2014-01-01T01:00:00Z'
  },
  'end': {
    'dateTime': '2014-01-01T20:20:20Z'
  }
  
  }


import argparse
import httplib2
import os
import sys
import pdb

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

def eventbuilder():
  event = {
  'summary': 'Appointment',
  'location': 'Somewhere',
  'start': {
    'dateTime': '2014-01-01T01:00:00Z'
  },
  'end': {
    'dateTime': '2014-01-01T20:20:20Z'
  },
  'description':'this is a test event',
  'extendedProperties':{
    'shared':{
      'testid':'B13_1230_twn'
    }
  }
  }
  return event


def insert_or_update(event, calendar):
  #given an event, either update an already-existing event or insert it
  #How do you find the already-existing event? It should start on the same day as this event, and also
  # have the same testid (saved in extendedProperties-shared-testid)
  doinsert = False
  updateThis = ''
  seqNum = 0
  target_testid = event['extendedProperties']['shared']['testid']
  nend = event['end']['dateTime']
  
  try:
    list_today = service.events().list(calendarId=calendar, orderBy="startTime", timeMin=event['start']['dateTime'], timeMax=nend, singleEvents=True).execute()['items']
    if len(list_today) == 0:
      doinsert = True
    for item in list_today:
      if item['extendedProperties']['shared']['testid'] == target_testid:
        updateThis = item['id']
        seqNum = int(item['sequence']) + 1
  except:
    doinsert = True

  event['sequence'] = str(seqNum)

  if doinsert:
    calendarevent = service.events().insert(body=event, calendarId=calendar).execute()
  else:
    #update instead
    calendarevent = service.events().update(body=event, calendarId=calendar, eventId=updateThis).execute()

  print calendarevent

def get_cal_id():
  cals = service.calendarList().list().execute()['items']
  id2 = cals[1]['id'] 

  #1 = testing.
  #2 = REAL
  #0 = default/ignore
  return id2


def main(argv):
  # Parse the command-line flags.
  flags = parser.parse_args(argv[1:])

  # If the credentials don't exist or are invalid run through the native client
  # flow. The Storage object will ensure that if successful the good
  # credentials will get written back to the file.
  storage = file.Storage('sample.dat')
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
    #print "Success! Now add code here."
    pass
  except client.AccessTokenRefreshError:
    print ("The credentials have been revoked or expired, please re-run"
      "the application to re-authorize")
    return

  id2 = get_cal_id()
  
  #Get a the first event summary
  #service.events().list(calendarId=id2).execute()['items'][0]['summary']
  event = eventbuilder()
  insert_or_update(event, id2)
  
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
if __name__ == '__main__':
  main(sys.argv)
