/**
 * program entry point
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 20-May-2023
 * @license see 'LICENSE' file
 */

#include "float_dlg.h"

#include <locale>
#include <string>
#include <iostream>

#include <QtCore/QLocale>
#include <QtWidgets/QApplication>


static inline void set_locales()
{
	std::ios_base::sync_with_stdio(false);

	::setlocale(LC_ALL, "C");
	std::locale::global(std::locale("C"));
	QLocale::setDefault(QLocale::C);
}


int main(int argc, char** argv)
{
	try
	{
		// application
		auto app = std::make_unique<QApplication>(argc, argv);
		app->setOrganizationName("tw");
		app->setApplicationName("float_tool");
		app->setApplicationVersion("0.1");
		set_locales();

		// main dialog
		auto dlg = std::make_unique<FloatDlg>();
		dlg->show();
		dlg->raise();
		dlg->activateWindow();

		return app->exec();
	}
	catch(const std::exception& ex)
	{
		std::cerr << ex.what() << std::endl;
	}

	return -1;
}
