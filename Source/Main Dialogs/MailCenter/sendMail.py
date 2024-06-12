#!/usr/bin/env python3

# HALO Modification to remove all secutiry and send through smtp.snolab.ca

import email
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
import smtplib
import optparse
import os
from os.path import basename

def send_mail(user, password, server, fromaddr, to, subject,
              message, attachments, filename):
    msg = MIMEMultipart()
    fromaddr = 'daq@daqN.halo-r.snolab.ca'
    if fromaddr == '':
        fromaddr = user + '@' + server
    msg['From'] = fromaddr
    msg['To'] = to
    msg['Subject'] = subject
    if filename:
        if os.path.exists(filename):
            f = open(filename)
            msg.attach(MIMEText(f.read(), 'plain'))
            f.close()
        else:
            'Email message in ' + filename + ' not found'
    else:
        s = message.split('\\n')
        message = ''
        for l in s:
            message += l + '\n'
        msg.attach(MIMEText(str(message), 'plain'))
    attachments.replace(' ', '')
    for fname in attachments.split(','):
        if not fname:
            continue
        if not os.path.exists(fname):
            print('Attachment ' + fname + ' not found')
            continue
        with open(fname, 'rb') as f:
            part = MIMEApplication(f.read(), Name=basename(fname))
            part['Content-Disposition'] = 'attachment; filename=' + basename(fname)
            msg.attach(part)
            f.close()
#    serv = smtplib.SMTP('smtp.' + server, 587)
    serv = smtplib.SMTP('smtp.snolab.ca', 25)
    serv.ehlo()
#    serv.starttls()
#    serv.ehlo()
#    serv.login(user, password)
    to.replace(' ', '')
    serv.sendmail(fromaddr, to.split(','), msg.as_string())
    serv.close()
    
if __name__ == '__main__':

    parser = optparse.OptionParser('%prog file [...]')
    parser.add_option('-u', type = 'str', dest = 'user',
                      help = 'user name', default = '')
    parser.add_option('-p', type = 'str', dest = 'password',
                      help = 'password', default = '')
    parser.add_option('-e', type = 'str', dest = 'server',
                      help = 'mail server name', default = '')
    parser.add_option('-F', type = 'str', dest = 'fromaddr',
                      help = 'from address', default = '')
    parser.add_option('-t', type = 'str', dest = 'to',
                     help = 'to address', default = '')
    parser.add_option('-s', type = 'str', dest = 'subject',
                      help = 'message subject', default = '')
    parser.add_option('-m', type = 'str', dest = 'message',
                      help = 'message content', default = '')
    parser.add_option('-a', type ='str', dest = 'attachments',
                      help = 'attachment filenames', default = '')
    parser.add_option('-f', type = 'str', dest = 'filename',
                      help = 'message filename', default = '')
    options, args = parser.parse_args()

    send_mail(options.user, options.password, options.server, options.fromaddr,
              options.to, options.subject, options.message, options.attachments,
              options.filename)

