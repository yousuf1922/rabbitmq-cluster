import http from "k6/http";
import { check } from "k6";

export const options = {
    vus: 10, // Number of virtual users
    duration: "30s", // Test duration
};

export default function () {
    let res = http.get("http://admin:securepassword@nginx:15675/api/overview");
    check(res, {
        "status is 200": (r) => r.status === 200,
    });
}
