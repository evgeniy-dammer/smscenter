class Message {
  String id;
  String phone;
  String message;
  String date;

  Message({
    this.id,
    this.phone,
    this.message,
    this.date
  });

  factory Message.fromMap(Map<String, dynamic> json) => new Message(
      id: json['id'],
      phone: json['phone'],
      message: json['message'],
      date: json['date']
  );
}