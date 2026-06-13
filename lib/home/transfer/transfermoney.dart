import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:modipay/home/transfer/transferconfirm.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import '../../utils/string.dart';

class TransferMoney extends StatefulWidget {
  final int contactId;
  final String contactName;
  final String contactPhone;
  final String contactCategory;

  const TransferMoney({
    Key? key,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.contactCategory,
  }) : super(key: key);

  @override
  State<TransferMoney> createState() => _TransferMoneyState();
}

class _TransferMoneyState extends State<TransferMoney> {
  late ColorNotifire notifire;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  final List<int> _quickAmounts = [50000, 100000, 200000, 500000];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateAmount(int val) {
    setState(() {
      _amountController.text = _currencyFormat.format(val);
    });
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);
    final balanceValue = double.tryParse(auth.userBalance.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final isBalanceZero = balanceValue <= 0;
    
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(amountText) ?? 0;
    final isInsufficient = amount > balanceValue;
    final dailyLimit = auth.dailyTransferLimit;
    final isOverLimit = amount > dailyLimit;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFF182974)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Transfer',
          style: TextStyle(
            fontFamily: 'Gilroy Bold',
            color: Color(0xFF182974),
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Recipient Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3567A9).withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3567A9).withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: notifire.getbluecolor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: notifire.getbluecolor,
                                fontFamily: 'Gilroy Bold',
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.contactName,
                                style: const TextStyle(
                                  color: Color(0xFF182974),
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.contactPhone,
                                style: const TextStyle(
                                  color: Color(0xFF3567A9),
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Balance Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nominal Transfer',
                        style: TextStyle(
                          color: Color(0xFF182974),
                          fontFamily: 'Gilroy Bold',
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isBalanceZero ? Colors.red.withOpacity(0.1) : notifire.getbluecolor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Saldo: Rp ${auth.userBalance}',
                          style: TextStyle(
                            color: isBalanceZero ? Colors.red : notifire.getbluecolor,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Amount Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isInsufficient ? Colors.red : (amount > 0 ? notifire.getbluecolor : const Color(0xFF3567A9).withOpacity(0.2)),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3567A9).withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "Rp",
                              style: TextStyle(
                                color: Color(0xFF182974),
                                fontSize: 24,
                                fontFamily: 'Gilroy Bold',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _amountController,
                                enabled: !isBalanceZero,
                                style: TextStyle(
                                  color: isInsufficient ? Colors.red : const Color(0xFF182974),
                                  fontSize: 32,
                                  fontFamily: 'Gilroy Bold',
                                ),
                                cursorColor: notifire.getbluecolor,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "0",
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                  hintStyle: TextStyle(
                                    fontSize: 32,
                                    color: const Color(0xFF3567A9).withOpacity(0.3),
                                    fontFamily: 'Gilroy Bold',
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    String plain = value.replaceAll(RegExp(r'[^0-9]'), '');
                                    if (plain.isNotEmpty) {
                                      _amountController.value = TextEditingValue(
                                        text: _currencyFormat.format(int.parse(plain)),
                                        selection: TextSelection.collapsed(offset: _currencyFormat.format(int.parse(plain)).length),
                                      );
                                    }
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        if (isInsufficient) ...[
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Saldo tidak mencukupi',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (isOverLimit) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Maksimum transfer harian Rp ${_currencyFormat.format(dailyLimit)}',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quick Amounts
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickAmounts.length,
                      itemBuilder: (context, index) {
                        final qAmt = _quickAmounts[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('Rp ${_currencyFormat.format(qAmt)}'),
                            selected: amount == qAmt.toDouble(),
                            onSelected: (selected) {
                              if (selected) _updateAmount(qAmt);
                            },
                            labelStyle: TextStyle(
                              color: amount == qAmt.toDouble() ? Colors.white : const Color(0xFF3567A9),
                              fontFamily: 'Gilroy Bold',
                              fontSize: 13,
                            ),
                            selectedColor: notifire.getbluecolor,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: amount == qAmt.toDouble() ? notifire.getbluecolor : const Color(0xFF3567A9).withOpacity(0.2),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Notes Input
                  const Text(
                    'Catatan (Opsional)',
                    style: TextStyle(
                      color: Color(0xFF182974),
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    enabled: !isBalanceZero,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF182974),
                      fontFamily: 'Gilroy Medium',
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "Tambah pesan untuk penerima...",
                      hintStyle: TextStyle(color: const Color(0xFF3567A9).withOpacity(0.4), fontSize: 14),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: const Color(0xFF3567A9).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: const Color(0xFF3567A9).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: notifire.getbluecolor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Bottom Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3567A9).withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: (isBalanceZero || isInsufficient || amount <= 0 || isOverLimit)
                  ? null
                  : () {
                      _showMyDialog(amount, auth.userPhone);
                    },
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: (isBalanceZero || isInsufficient || amount <= 0 || isOverLimit)
                      ? const Color(0xFF3567A9).withOpacity(0.2)
                      : notifire.getbluecolor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (isBalanceZero || isInsufficient || amount <= 0 || isOverLimit)
                      ? []
                      : [
                          BoxShadow(
                            color: notifire.getbluecolor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: const Center(
                  child: Text(
                    'Lanjutkan',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMyDialog(double amount, String senderPhone) async {
    final formattedAmount = 'Rp ${_currencyFormat.format(amount)}';
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(32.0),
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(
                Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24),
            height: height / 1.7,
            child: Column(
              children: [
                Image.asset(
                  "images/totaltransfer.png",
                  height: height / 10,
                ),
                const SizedBox(height: 16),
                Text(
                  CustomStrings.totaltransfer,
                  style: TextStyle(
                    color: const Color(0xFF3567A9),
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 50,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formattedAmount,
                  style: TextStyle(
                    color: const Color(0xFF182974),
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 30,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      Text(
                        CustomStrings.transferdetails,
                        style: TextStyle(
                          color: const Color(0xFF182974),
                          fontFamily: 'Gilroy Bold',
                          fontSize: height / 50,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow('Dari', 'Modipay ($senderPhone)'),
                const SizedBox(height: 12),
                _detailRow('Ke', '${widget.contactName} (${widget.contactPhone})'),
                const SizedBox(height: 12),
                _detailRow('Nominal', formattedAmount),
                const SizedBox(height: 12),
                _detailRow('Biaya Admin', 'Gratis', isFree: true),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: const Divider(thickness: 0.6, color: Color(0xFF3567A9)),
                ),
                _detailRow('Total Bayar', formattedAmount, isBold: true),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: _dialogButton(Colors.white, 'Batal', const Color(0xFF182974)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TransferConfirm(
                                  receiverId: widget.contactId,
                                  amount: amount,
                                  notes: _notesController.text,
                                  receiverName: widget.contactName,
                                ),
                              ),
                            );
                          },
                          child: _dialogButton(notifire.getbluecolor, 'Konfirmasi', Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool isFree = false, bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width / 20),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF3567A9), fontFamily: 'Gilroy Medium', fontSize: 13),
          ),
          const Spacer(),
          if (isFree)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: notifire.getbluecolor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'GRATIS',
                style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Gilroy Bold'),
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF182974),
                  fontFamily: isBold ? 'Gilroy Bold' : 'Gilroy Medium',
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dialogButton(Color clr, String txt, Color txtClr) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: clr,
        borderRadius: BorderRadius.circular(24),
        border: clr == Colors.white ? Border.all(color: const Color(0xFF3567A9).withOpacity(0.3)) : null,
      ),
      child: Center(
        child: Text(
          txt,
          style: TextStyle(color: txtClr, fontSize: 14, fontFamily: 'Gilroy Bold'),
        ),
      ),
    );
  }
}
