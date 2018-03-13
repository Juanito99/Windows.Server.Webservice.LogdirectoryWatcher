## Monitor Webservers Log directories

Simple Management Pack which monitors the webserver's log directory size.


### Introduction:
IIS, Apache and Tomcat can write log files. It happens not seldom that a webservice log directory occupies large space or even causes disk filling up.

In the default configuration a warning state occurs once 2.5 GB disk space is used by logs. An error state plus a message is thrown once more than 5 GB is taken.
Thresholds and alert behaviour can be overridden as usual.



### State Views:
![StateView_Listen](https://raw.githubusercontent.com/Juanito99/Network.Windows.Computer.NetstatWatcher/master/PicturesForGitWebSite/stateview%20showing%20listeningPorts.png)

![StateView_Connection](https://raw.githubusercontent.com/Juanito99/Network.Windows.Computer.NetstatWatcher/master/PicturesForGitWebSite/stateview%20showing%20tcpConnections.png)


### More information on:
[Documentation](https://github.com/Juanito99/Network.Windows.Computer.NetstatWatcher/blob/master/Documentation/Monitor%20any%20network-connection%20or%20listening%20port%20with%20SCOM%20-%20Git.pdf)


### Downloads:
[ManagementPack-Sealed](https://github.com/Juanito99/Network.Windows.Computer.NetstatWatcher/blob/master/Network.Windows.Computer.NetstatWatcher/Network.Windows.Computer.NetstatWatcher/bin/Release/Network.Windows.Computer.NetstatWatcher.mpb) 

[ManagementPack-UnSealed](https://github.com/Juanito99/Network.Windows.Computer.NetstatWatcher/blob/master/Network.Windows.Computer.NetstatWatcher/Network.Windows.Computer.NetstatWatcher/bin/Debug/Network.Windows.Computer.NetstatWatcher.mpb) 

[Source for VSAE 2015](https://github.com/Juanito99/Network.Windows.Computer.NetstatWatcher/tree/master/Network.Windows.Computer.NetstatWatcher/Network.Windows.Computer.NetstatWatcher)



### Community Management Pack:
Keep this and many other management packs automatically up to date by installing the [Community Management Pack](https://squaredup.com/landing-pages/the-scom-community-mp-catalog)




### License Terms

Windows.Server.Webservice.LogdirectoryWatcher
Copyright (C) 2018 Ruben Zimmermann (Juanito99)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.