/**
 * floating point tool
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 20-May-2023
 * @license see 'LICENSE' file
 */

#ifndef __FLOAT_DLG_H__
#define __FLOAT_DLG_H__


#include "arb_float.h"

#include <QtWidgets/QDialog>
#include <QtWidgets/QLineEdit>
#include <QtWidgets/QSpinBox>


class FloatDlg : public QDialog
{
public:
	FloatDlg(QWidget* parent = nullptr);
	virtual ~FloatDlg();


protected:
	void SetupGUI();

	void FloatChanged(const QString&);
	void FloatBinChanged(const QString&);

	void ExponentLengthChanged(int len);
	void MantissaLengthChanged(int len);

	virtual void closeEvent(QCloseEvent *evt) override;


private:
	FloatDlg(const FloatDlg&) = delete;
	const FloatDlg& operator=(const FloatDlg&) = delete;


private:
	ArbFloat<> m_value{32, 8};

	QLineEdit *m_editFloat{};
	QLineEdit *m_editFloatExpr{};
	QLineEdit *m_editFloatBin{};

	QSpinBox *m_spinExpLen{}, *m_spinMantLen{};
};


#endif
