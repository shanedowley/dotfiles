return {
	s("html5", {
		t({ "<!DOCTYPE html>", '<html lang="en">', "<head>" }),
		t({ '  <meta charset="UTF-8">', "  <title>" }),
		i(1, "Document"),
		t({ "</title>", '  <link rel="stylesheet" href="styles.css">', "</head>", "<body>" }),
		t({ "  " }),
		i(2, "<h1>Hello CSS!</h1>"),
		t({ "", "</body>", "</html>" }),
	}),
}
