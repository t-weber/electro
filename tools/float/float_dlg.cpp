/**
 * floating point tool
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 20-May-2023
 * @license see 'LICENSE' file
 */

#include "float_dlg.h"

#include <limits>

#include <QtCore/QSettings>
#include <QtWidgets/QGridLayout>
#include <QtWidgets/QSpacerItem>
#include <QtWidgets/QDialogButtonBox>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QAbstractButton>
#include <QtWidgets/QLineEdit>
#include <QtWidgets/QFrame>
#include <QtWidgets/QLabel>


FloatDlg::FloatDlg(QWidget* parent) : QDialog{parent}
{
	SetupGUI();
}


FloatDlg::~FloatDlg()
{
}


void FloatDlg::SetupGUI()
{
	setWindowTitle("Floating Point Tool");

	// create gui grid
	QGridLayout* grid = new QGridLayout{this};
	grid->setSpacing(4);
	grid->setContentsMargins(8, 8, 8, 8);

	// float value
	QLabel *labelFloat = new QLabel("Float:", this);
	QLabel *labelFloatExpr = new QLabel("Expression:", this);
	QLabel *labelFloatBin = new QLabel("Binary:", this);
	QLabel *labelFloatHex = new QLabel("Hexadecimal:", this);
	labelFloat->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
	labelFloatExpr->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
	labelFloatBin->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
	labelFloatHex->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);

	m_editFloat = new QLineEdit(this);
	m_editFloatExpr = new QLineEdit(this);
	m_editFloatBin = new QLineEdit(this);
	m_editFloatHex = new QLineEdit(this);
	m_editFloatExpr->setReadOnly(true);

	int grid_y = 0;
	grid->addWidget(labelFloat, grid_y, 0, 1, 1);
	grid->addWidget(m_editFloat, grid_y++, 1, 1, 2);
	grid->addWidget(labelFloatExpr, grid_y, 0, 1, 1);
	grid->addWidget(m_editFloatExpr, grid_y++, 1, 1, 2);
	grid->addWidget(labelFloatBin, grid_y, 0, 1, 1);
	grid->addWidget(m_editFloatBin, grid_y++, 1, 1, 2);
	grid->addWidget(labelFloatHex, grid_y, 0, 1, 1);
	grid->addWidget(m_editFloatHex, grid_y++, 1, 1, 2);

	// float settings
	QFrame *line = new QFrame{this};
	line->setFrameShape(QFrame::HLine);
	grid->addWidget(line, grid_y++, 0, 1, 3);

	QLabel *labelLengths = new QLabel("Bit Lengths:", this);
	labelLengths->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
	grid->addWidget(labelLengths, grid_y, 0, 1, 1);

	m_spinExpLen = new QSpinBox{this};
	m_spinMantLen = new QSpinBox{this};
	m_spinExpLen->setPrefix("e = ");
	m_spinMantLen->setPrefix("m = ");
	m_spinExpLen->setMinimum(1);
	m_spinExpLen->setMaximum(999);
	m_spinMantLen->setMinimum(1);
	m_spinMantLen->setMaximum(999);
	m_spinExpLen->setValue((int)m_value.GetExponentLength());
	m_spinMantLen->setValue((int)m_value.GetMantissaLength());

	grid->addWidget(m_spinExpLen, grid_y, 1, 1, 1);
	grid->addWidget(m_spinMantLen, grid_y++, 2, 1, 1);

	QPushButton *btnHalfPrec = new QPushButton{"Half Precision", this};
	QPushButton *btnSinglePrec = new QPushButton{"Single Precision", this};
	QPushButton *btnDoublePrec = new QPushButton{"Double Precision", this};
	QPushButton *btnQuadPrec = new QPushButton{"Quad Precision", this};
	grid->addWidget(btnHalfPrec, grid_y, 1, 1, 1);
	grid->addWidget(btnSinglePrec, grid_y++, 2, 1, 1);
	grid->addWidget(btnDoublePrec, grid_y, 1, 1, 1);
	grid->addWidget(btnQuadPrec, grid_y++, 2, 1, 1);

	// OK button
	QSpacerItem *spacer = new QSpacerItem{1, 1, QSizePolicy::Fixed, QSizePolicy::Expanding};
	grid->addItem(spacer, grid->rowCount(), 0, 1, 3);

	QDialogButtonBox *buttonbox = new QDialogButtonBox{this};
	buttonbox->setStandardButtons(QDialogButtonBox::Ok);
	connect(buttonbox, &QDialogButtonBox::clicked,
		[this, buttonbox](QAbstractButton *btn) -> void
        {
		switch(buttonbox->buttonRole(btn))
		{
			case QDialogButtonBox::AcceptRole:
				this->accept();
				this->close();
				break;
			case QDialogButtonBox::RejectRole:
				this->reject();
				this->close();
				break;
			default:
				break;
		}
	});
	grid->addWidget(buttonbox, grid->rowCount(), 0, 1, 3);

	// connections
	connect(m_editFloat, static_cast<void (QLineEdit::*)(
		const QString&)>(&QLineEdit::textEdited),
		this, &FloatDlg::FloatChanged);
	connect(m_editFloatBin, static_cast<void (QLineEdit::*)(
		const QString&)>(&QLineEdit::textEdited),
		this, &FloatDlg::FloatBinChanged);
	connect(m_editFloatHex, static_cast<void (QLineEdit::*)(
		const QString&)>(&QLineEdit::textEdited),
		this, &FloatDlg::FloatHexChanged);
	connect(m_spinExpLen, static_cast<void (QSpinBox::*)(int)>(
		&QSpinBox::valueChanged),
		this, &FloatDlg::ExponentLengthChanged);
	connect(m_spinMantLen, static_cast<void (QSpinBox::*)(int)>(
		&QSpinBox::valueChanged),
		this, &FloatDlg::MantissaLengthChanged);
	connect(btnHalfPrec, &QAbstractButton::clicked,[this]()
	{
		m_spinMantLen->setValue(10);
		m_spinExpLen->setValue(5);
	});
	connect(btnSinglePrec, &QAbstractButton::clicked,[this]()
	{
		m_spinMantLen->setValue(23);
		m_spinExpLen->setValue(8);
	});
	connect(btnDoublePrec, &QAbstractButton::clicked,[this]()
	{
		m_spinMantLen->setValue(52);
		m_spinExpLen->setValue(11);
	});
	connect(btnQuadPrec, &QAbstractButton::clicked,[this]()
	{
		m_spinMantLen->setValue(112);
		m_spinExpLen->setValue(15);
	});

	// restore settings
	QSettings sett{this};
	if(sett.contains("dlg_geo"))
		restoreGeometry(sett.value("dlg_geo").toByteArray());

	if(sett.contains("exp_len") && sett.contains("mant_len"))
	{
		m_spinExpLen->setValue(sett.value("exp_len").toInt());
		m_spinMantLen->setValue(sett.value("mant_len").toInt());
	}

	if(sett.contains("float_value"))
		m_editFloat->setText(sett.value("float_value").toString());
	else
		m_editFloat->setText("0");

	// recalculate
	FloatChanged(m_editFloat->text());
}


void FloatDlg::SetNumberToolTips()
{
	std::ostringstream ostrExp;
	ostrExp << "Length of the exponent. Bias: " << m_value.GetExponentBias() << ".";

	m_spinExpLen->setToolTip(ostrExp.str().c_str());
	m_spinMantLen->setToolTip("Length of the mantissa.");

	std::ostringstream ostrVal;
	ostrVal
		<< "Sign: " << m_value.GetSign()
		<< "; raw exponent: " << m_value.GetExponent(false)
		<< ", exponent: " << m_value.GetExponent(true)
		<< "; raw mantissa: " << m_value.GetMantissa(false)
		<< ", mantissa: " << m_value.GetMantissa(true)
		<< ".";

	m_editFloatBin->setToolTip(ostrVal.str().c_str());

	std::ostringstream ostrValHex;
	ostrValHex << std::hex
		<< "Sign: " << m_value.GetSign()
		<< ", raw exponent: 0x" << m_value.GetExponent(false)
		<< ", raw mantissa: 0x" << m_value.GetMantissa(false)
		<< ".";

	m_editFloatHex->setToolTip(ostrValHex.str().c_str());
}


void FloatDlg::ExponentLengthChanged(int exp_len)
{
	int mant_len = m_spinMantLen->value();
	//int total_len = (int)m_value.GetTotalLength();
	int total_len = mant_len + exp_len + 1;
	ArbFloat<> new_value = ArbFloat<>(total_len, exp_len);

	m_value = std::move(new_value);

	// recalculate
	FloatChanged(m_editFloat->text());
}


void FloatDlg::MantissaLengthChanged(int mant_len)
{
	int exp_len = m_spinExpLen->value();
	int total_len = mant_len + exp_len + 1;
	ArbFloat<> new_value = ArbFloat<>(total_len, exp_len);

	m_value = std::move(new_value);

	// recalculate
	FloatChanged(m_editFloat->text());
}


void FloatDlg::FloatChanged(const QString& txt)
{
	ArbFloat<> f(64, 11);
	f.InterpretFrom<double>(txt.toDouble());
	//f.PrintInfos();
	m_value.ConvertFrom(f);

	m_editFloatExpr->setText(m_value.PrintExpression(false, false, false).c_str());
	m_editFloatExpr->setToolTip(m_value.PrintExpression(true, true, true).c_str());
	m_editFloatBin->setText(m_value.PrintBinary(true, false).c_str());
	m_editFloatHex->setText(m_value.PrintHex(false).c_str());

	SetNumberToolTips();
}


void FloatDlg::FloatBinChanged(const QString& txt)
{
	m_value.SetBinary(txt.toStdString());

	ArbFloat<> f(64, 11);
	f.ConvertFrom(m_value);
	double d = f.InterpretAs<double>();

	QString str;
	str.setNum(d, 'g', std::numeric_limits<double>::digits10);
	m_editFloat->setText(str);
	m_editFloatExpr->setText(m_value.PrintExpression().c_str());
	m_editFloatExpr->setToolTip(m_value.PrintExpression(true, true, true).c_str());
	m_editFloatHex->setText(m_value.PrintHex(false).c_str());
}


void FloatDlg::FloatHexChanged(const QString& txt)
{
	m_value.SetHex(txt.toStdString());

	ArbFloat<> f(64, 11);
	f.ConvertFrom(m_value);
	double d = f.InterpretAs<double>();

	QString str;
	str.setNum(d, 'g', std::numeric_limits<double>::digits10);
	m_editFloat->setText(str);
	m_editFloatExpr->setText(m_value.PrintExpression().c_str());
	m_editFloatExpr->setToolTip(m_value.PrintExpression(true, true, true).c_str());
	m_editFloatBin->setText(m_value.PrintBinary(true, false).c_str());
}


void FloatDlg::closeEvent(QCloseEvent *evt)
{
	// save settings
	QSettings sett{this};
	sett.setValue("dlg_geo", saveGeometry());
	sett.setValue("float_value", m_editFloat->text());
	sett.setValue("exp_len", m_spinExpLen->value());
	sett.setValue("mant_len", m_spinMantLen->value());

	QDialog::closeEvent(evt);
}
