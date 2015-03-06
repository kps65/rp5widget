rp5widget
=========

-------------------------------------------
RP5.RU weather informer for Awesome WM 3.5+
-------------------------------------------

Author: Konstantin Savov

Version: 0.9beta

License: GNU-GPLv2

Source: https://github.com/kps65/rp5widget

Description
-----------

Provides awesome widgets for rp5.ru weather forecast service.
Uses rp5 html and image informers and shows forecasts for one or
more locations with naughty notifications.

Usage 
-----

Example of code to put somewhere in rc.lua before wibox
definitions:

```lua
	rp5 = require("rp5widget")
	-- location definitions
	rp5.loc = {
		{ id = 5491, name = "Москва\n(юго-запад, МГУ)", },
		{ id = 5483, name = "Москва (ВДНХ)", },
	}
	-- widget initialization
	rp5widgets = rp5.widgets()
```

where rp5widgets is a set of widgets
(wibox.layout.fixed.horizontal) for wibox.

Default mouse bindings:

	left: show complete set of forecast notifications

	ctrl+left: open rp5.ru in brower for the location
	
	right: force forecast refresh

Screenshots
-----------

Tooltip:

![tooltip](https://leto43f.storage.yandex.net/rdisk/9980a58aee4084a729369e0c51d57f2ad8cc03a8f3946752f0d6195b081b62bd/inf/QYOiO08QvppLwy5DPU0OpjPyRnRjafKutU6LF62Css5dB7RdyrqFZOTamndTckezRDaiTBqdZK9_ZMTWVOWFUA==?uid=0&filename=tooltip.png&disposition=inline&hash=&limit=0&content_type=image%2Fpng&tknv=v2&rtoken=aa1d09f4d6d00235b91b1fbf69a82eb0&force_default=no)

Forecast notification:

![forecast](https://leto34g.storage.yandex.net/rdisk/b7197bd44916e93a8d66ceb47f7894adc037495e9733967fa4563db562944bda/inf/fG-g7Vb2XG5LWN9_9SJdxcLzOfyO5oMo2S5W29E8OIkdlI0UUJ16tL8Lrnzi9nC2q_J6bpmRyOJonT3VoXnDag==?uid=0&filename=forecast.png&disposition=inline&hash=&limit=0&content_type=image%2Fpng&tknv=v2&rtoken=aa1d09f4d6d00235b91b1fbf69a82eb0&force_default=no)
