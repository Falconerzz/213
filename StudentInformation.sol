// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StudentInformation {

    // Struct สำหรับเก็บข้อมูลนักเรียน
    struct Student {
        string studentID;
        string firstName;
        string surname;
        string houseNumber;
        string streetName;
        string city;
        string postcode;
    }

    // Mapping สำหรับเก็บข้อมูลนักเรียนโดยใช้ studentID
    mapping(string => Student) private students;

    // Event ที่จะถูกกระตุ้นเมื่อมีการเพิ่มข้อมูลนักเรียน
    event StudentAdded(string studentID, string firstName, string surname);

    // ฟังก์ชันตรวจสอบรหัสนักศึกษา
    function isValidID(string memory studentID) internal pure returns (bool) {
        // ตรวจสอบความยาวของรหัส
        if (bytes(studentID).length != 8) return false;

        // ตรวจสอบตัวอักษรแรก
        if (bytes(studentID)[0] != 'B' && bytes(studentID)[0] != 'M' && bytes(studentID)[0] != 'D') return false;

        // คำนวณ checksum
        uint checksum = 0;
        for (uint i = 1; i < 7; i++) {
            checksum += (uint(uint8(bytes(studentID)[i])) - 48) * (i % 2 == 0 ? 49 : 7);
        }
        checksum = checksum % 10;

        // ตรวจสอบตัวเลขสุดท้าย
        return checksum == uint(uint8(bytes(studentID)[7])) - 48;
    }

    // ฟังก์ชันเพิ่มข้อมูลนักเรียน
    function addStudent(
        string memory studentID,
        string memory firstName,
        string memory surname,
        string memory houseNumber,
        string memory streetName,
        string memory city,
        string memory postcode
    ) public {
        // ตรวจสอบความถูกต้องของรหัสนักศึกษา
        require(isValidID(studentID), "Invalid student ID");

        // บันทึกข้อมูลนักเรียนใน Mapping
        students[studentID] = Student({
            studentID: studentID,
            firstName: firstName,
            surname: surname,
            houseNumber: houseNumber,
            streetName: streetName,
            city: city,
            postcode: postcode
        });

        // กระตุ้น Event เมื่อเพิ่มข้อมูลนักเรียน
        emit StudentAdded(studentID, firstName, surname);
    }

    // ฟังก์ชันค้นหาข้อมูลนักเรียน
    function getStudent(string memory studentID) public view returns (
        string memory firstName,
        string memory surname,
        string memory houseNumber,
        string memory streetName,
        string memory city,
        string memory postcode
    ) {
        // ดึงข้อมูลนักเรียนจาก Mapping
        Student memory student = students[studentID];

        // ส่งคืนข้อมูลของนักเรียน
        return (
            student.firstName,
            student.surname,
            student.houseNumber,
            student.streetName,
            student.city,
            student.postcode
        );
    }
}
