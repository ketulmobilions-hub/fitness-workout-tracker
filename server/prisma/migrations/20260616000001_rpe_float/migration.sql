-- AlterTable: change rpe from integer to float to support 0.5 increments (e.g. RPE 6.5, 7.5)
ALTER TABLE "set_logs" ALTER COLUMN "rpe" TYPE DOUBLE PRECISION;
