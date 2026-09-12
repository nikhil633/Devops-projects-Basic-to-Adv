package model

import (
	"time"
	"gorm.io/gorm"
)

type User struct {
	ID        uint           `gorm:"primaryKey;autoIncrement" json:"id"`
	Name      string         `gorm:"not null"                 json:"name"      binding:"required"`
	Email     string         `gorm:"uniqueIndex;not null"     json:"email"     binding:"required,email"`
	Role      string         `gorm:"default:viewer"           json:"role"`
	Active    bool           `gorm:"default:true"             json:"active"`
	CreatedAt time.Time      `                                json:"created_at"`
	UpdatedAt time.Time      `                                json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index"                    json:"-"`
}

type CreateUserRequest struct {
	Name  string `json:"name"  binding:"required"`
	Email string `json:"email" binding:"required,email"`
	Role  string `json:"role"`
}

type UpdateUserRequest struct {
	Name   string `json:"name"`
	Role   string `json:"role"`
	Active *bool  `json:"active"`
}
