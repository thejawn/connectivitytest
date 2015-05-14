# connectivitytest
To measure the uptime/outages of the local network vs. public network... So that customers can go to their ISP with some proof that their internet sucks.


The program is two parts: 

The client can be run as a task in the background, or you can run it in the foreground. Just set your options in the config file

The Server just need a MySql or Maria DB, copy and paste TableMaker.txt into the database terminal.

I know, nothing is commented, I should read the Pragmatic Programmer again.

You can run the client on as many computers as you'd like, and the server will automatically pick them up, and log them separately. It will also create an 'others' average, for how often the other computers disconnect.



This is my first GitHub Entry... good luck
