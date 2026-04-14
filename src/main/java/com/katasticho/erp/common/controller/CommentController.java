package com.katasticho.erp.common.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.entity.EntityComment;
import com.katasticho.erp.common.service.CommentService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/comments")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;

    @PostMapping("/{entityType}/{entityId}")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<EntityComment> addComment(
            @PathVariable String entityType,
            @PathVariable UUID entityId,
            @RequestBody String text) {
        return ApiResponse.created(commentService.addComment(entityType, entityId, text));
    }

    @GetMapping("/{entityType}/{entityId}")
    public ApiResponse<Page<EntityComment>> list(
            @PathVariable String entityType,
            @PathVariable UUID entityId,
            @PageableDefault(size = 20) Pageable pageable) {
        return ApiResponse.ok(commentService.listComments(entityType, entityId, pageable));
    }

    @DeleteMapping("/{commentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID commentId) {
        commentService.deleteComment(commentId);
    }
}
